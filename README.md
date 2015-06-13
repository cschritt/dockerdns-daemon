# docker-dns-daemon
docker-dns-daemon listens on docker events and dynamically updates a given dns zone. It adds or deletes A and PTR
records depending on the event (start, stop, die, kill).

## prerequisites
* docker: http://docker.io
* dns server with configured zone for dynamic updates
* ruby (tested on: 2.2.1)
* the following ruby gems:
  * docker-api: https://github.com/swipely/docker-api
  * dnsruby: https://github.com/alexdalitz/dnsruby
  * parseconfig: https://github.com/datafolklabs/ruby-parseconfig

## getting started
* configure your dns server to allow dynamic updates, see http://docstore.mik.ua/orelly/networking_2ndEd/dns/ch10_02.htm (TSIG-signed updates are not supported yet)
* docker-dns.conf needs to be edited to your needs.

## usage
    Usage: docker-dns-daemon [options]
    
    Process options:
      -d, --daemonize                  run daemonized in the background (default: false)
      -c, --config CONFIGFILE          the config file
      -p, --pid PIDFILE                the pid filename
      -l, --log LOGFILE                the log filename
    
    Ruby options:
      -I, --include PATH               an additional $LOAD_PATH (may be used more than once)
          --debug                      set $DEBUG to true
          --warn                       enable warnings
    
    Common options:
      -h, --help
