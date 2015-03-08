require 'docker'
require 'dnsruby'
require_relative 'server.rb'

class DockerDNS 

  #==========================================================================
  def self.run!(config)
    DockerDNS.new(config).run!
  end
  #==========================================================================

  attr_reader :config
	
  def initialize(config)
    @config = config
	@domain = domain
    @reversezone = reversezone
    @dnsserver = dnsserver
  end

  def domain
	config["domain"]
  end
  
  def reversezone
	config["reversezone"]
  end
  
  def dnsserver
    config["dnsserver"]
  end
	
  def run!
	Docker.options[:read_timeout] = 5
    begin
		Docker::Event.stream do |event| 
		  if event.status == "create" then
			next
		  elsif event.status == "start" then
			puts "caught event #{event.status} for container id #{event.id}"
			dnsAddOrUpdate(event.id, domain, reversezone, dnsserver)
		  elsif event.status == "die" || event.status == "kill" || event.status == "stop" then
			puts "caught event #{event.status} for container id #{event.id}"
			dnsDelete(event.id)
		  else
			puts "Ignoring Docker Event #{event.status}"
		  end
		end
	rescue Docker::Error::TimeoutError => e
		retry
	rescue Exception => e
		puts "Error while streaming events: #{e}"
	end
  end
 
  def getContainerIP(id)
    ipAddress = Docker::Container.get(id).json["NetworkSettings"]["IPAddress"]
    return ipAddress
  end

  def getContainerName(id)
    hostname = Docker::Container.get(id).json["Config"]["Hostname"]
    return hostname
  end

  def getARecord(fqdn)
    resolver = Dnsruby::Resolver.new(dnsserver).query(fqdn)
	ipAddress = resolver.answer[0].address.to_s
	return ipAddress
  end

  def getPtrRecord(ipAddress)
	resolver = Dnsruby::Resolver.new(dnsserver).query(ipAddress, "PTR")
	fqdn = resolver.answer[0].domainname.to_s
	return fqdn
  end

  def setARecord(ipAddress, hostname, domain)
    record = "#{hostname}.#{domain}"    
    puts "setting a-record #{record}"
    resolver = Dnsruby::Resolver.new(dnsserver)
    update = Dnsruby::Update.new(domain)
    # make sure there is no record yet
    update.absent(record, 'A')
    # add record
	puts "update.add(#{record}, 'A', 600, #{ipAddress})"
    update.add(record, 'A', 600, ipAddress)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def deleteARecord(ipAddress, hostname, domain)
    record = "#{hostname}.#{domain}"    
    puts "deleting a-record #{record}"
    resolver = Dnsruby::Resolver.new(dnsserver)
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

  def setPtrRecord(ipAddress, hostname, domain, reversezone)
    record = "#{ipAddress.split('.').last}.#{reversezone}"
	fqdn = "#{hostname}.#{domain}"
    puts "setting ptr-record #{record}"
    resolver = Dnsruby::Resolver.new(dnsserver)
    update = Dnsruby::Update.new(reversezone)
	# make sure there is no record yet
    update.absent(record)
    # add record
	puts "update.add(#{record}, 'PTR', 600, #{fqdn})"
    update.add(record, "PTR", 600, fqdn)
    # send update
    begin
      reply = resolver.send_message(update)
      puts "Update succeeded"
    rescue Exception => e
      puts "Update failed: #{e}"
    end
  end

  def deletePtrRecord(ipAddress, hostname, domain, reversezone)
	record = "#{ipAddress.split('.').last}.#{reversezone}"
	fqdn = "#{hostname}.#{domain}"
    puts "deleting ptr-record #{record}"
    resolver = Dnsruby::Resolver.new(dnsserver)
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
  
  def dnsAddOrUpdate(id, domain, reversezone, dnsserver)
    hostname = getContainerName(id)
    ipAddress = getContainerIP(id)
    setARecord(ipAddress, hostname, domain)
    setPtrRecord(ipAddress, hostname, domain, reversezone)
	getARecord("#{hostname}.#{domain}")
	getPtrRecord(ipAddress)
  end


  def dnsDelete(id)
    hostname = getContainerName(id)
    ipAddress = getARecord("#{hostname}.#{domain}")
	deleteARecord(ipAddress, hostname, domain)
	deletePtrRecord(ipAddress, hostname, domain, reversezone)
  end
end
