require 'docker'
require 'dnsruby'

module DockerDNS

  #==========================================================================
  def self.run!(config)
    DockerDNS.new(config).run!
  end
  #==========================================================================

  def initialize(config)
    @config = config
  end

  def domain
	  @config["domain"]
  end

  def reversezone
	  @config["reversezone"]
  end

  def resolver
    @resolver ||= Dnsruby::Resolver.new(@config['dnsserver'])
  end

  def ttl
    @config["ttl"]
  end

  def docker_url
    @config["dockerurl"] || '/var/run/docker.sock'
  end

  def run!
  	Docker.url = docker_url
  	Docker.options[:read_timeout] = 5
    begin
  		Docker::Event.stream do |event|
  		  case event.status
        when "create"
  			  next
  		  when "start"
  			  puts "caught event #{event.status} for container id #{event.id}"
  			  create_or_update_dns_records!(event.id, domain)
  		  when "die", "kill", "stop", "destroy"
  			  puts "caught event #{event.status} for container id #{event.id}"
  			  delete_dns_records!(event.id)
  		  else
  			  puts "Ignoring Docker Event #{event.status}"
  		  end
  		end
  	rescue Docker::Error::TimeoutError, Excon::Errors::SocketError
  		retry
  	rescue StandardException => e
  		puts "Error while streaming events: #{e}"
  	end
  end

  def container_ip(id)
    Docker::Container.get(id).json["NetworkSettings"]["IPAddress"]
  end

  def container_name(id)
    Docker::Container.get(id).json["Config"]["Hostname"]
  end

  def a_record(fqdn)
    resolver.answer.first.address.to_s
  end

  def ptr_record(ipAddress)
    resolver.query(ipAddress, "PTR").answer.first.domainname.to_s
  end

  def set_a_record(ipAddress, hostname)
    record = "#{hostname}.#{domain}"
    puts "setting a-record #{record}"
    update = Dnsruby::Update.new(domain)
    # add record
	  puts "update.add(#{record}, 'A', #{ttl}, #{ipAddress})"
    update.add(record, 'A', ttl, ipAddress)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def delete_a_record(ipAddress, hostname)
    record = "#{hostname}.#{domain}"
    puts "deleting a-record #{record}"
  	update = Dnsruby::Update.new(domain)
  	# delete record
  	puts "update.delete(#{record})"
    update.delete(record)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def set_ptr_record(ipAddress, hostname)
    record = "#{ipAddress.split('.').last}.#{reversezone}"
	  fqdn = "#{hostname}.#{domain}"
    puts "setting ptr-record #{record}"
    update = Dnsruby::Update.new(reversezone)
    # add record
	  puts "update.add(#{record}, 'PTR', #{ttl}, #{fqdn})"
    update.add(record, 'PTR', ttl, fqdn)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def delete_ptr_record(ipAddress, hostname)
  	record = "#{ipAddress.split('.').last}.#{reversezone}"
  	fqdn = "#{hostname}.#{domain}"
    puts "deleting ptr-record #{record}"
    update = Dnsruby::Update.new(reversezone)
    # delete record
	  puts "update.delete(#{record})"
    update.delete(record)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def create_or_update_dns_records!(id)
    hostname = container_name(id)
    ipAddress = container_ip(id)
    set_a_record(ipAddress, hostname)
    set_ptr_record(ipAddress, hostname)
  	a_record("#{hostname}.#{domain}")
  	ptr_record(ipAddress)
  end


  def delete_dns_records!(id)
    hostname = container_name(id)
    ipAddress = a_record("#{hostname}.#{domain}")
    delete_a_record(ipAddress, hostname)
  	delete_ptr_record(ipAddress, hostname)
  end
end
