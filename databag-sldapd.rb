#!/usr/bin/env ruby

# This is an ldap server designed to load user data from a chef server
# databag, and then present it.
#
# It's base on the examples at
# https://github.com/inscitiv/ruby-ldapserver/blob/master/examples
#
# There is no validation, and not authentication.

# ldapsearch -x -H ldap://127.0.0.1:1389/ -b "" "(objectclass=*)"
# ldapsearch -x -H ldap://127.0.0.1:1389/ -b "" "(mail=fred*)"
# ldapsearch -x -H ldap://127.0.0.1:1389/ -b "" "(&(mail=fred*)(mail=*org))"
# ldapsearch -x -H ldap://127.0.0.1:1389/ -b "" "(&(id=seph)(groups=bastion-login))"
# ldapsearch -x -H ldap://127.0.0.1:1389/ -b "" "(&(status=active)(groups=bastion-login))" id

$debug = true

require 'ldap/server'
require 'chef-api'


# We subclass the Operation class, overriding the methods to do what we need

class HashOperation < LDAP::Server::Operation
  def initialize(connection, messageID, hash)
    super(connection, messageID)
    @hash = hash   # an object reference to our directory data
  end

  def setup_chef()
    ChefAPI.configure do |config|
      config.endpoint = CHEFURL
      config.client = CHEFUSER
      config.key    = CHEFPEM
    end

    connection = ChefAPI::Connection.new(
                                         endpoint: CHEFURL
                                         client:   CHEFUSER
                                         key:      CHEFPEM
                                         )
    return connection
  end

  def search(basedn, scope, deref, filter)
    basedn.downcase!

    case scope
    when LDAP::Server::BaseObject
      # client asked for single object by DN
      obj = @hash[basedn]
      raise LDAP::ResultError::NoSuchObject unless obj
      send_SearchResultEntry(basedn, obj) if LDAP::Server::Filter.run(filter, obj)

    when LDAP::Server::WholeSubtree
      @hash.each do |dn, av|
        #next unless dn.index(basedn, -basedn.length)    # under basedn?
        next unless LDAP::Server::Filter.run(filter, av)  # attribute filter?
        send_SearchResultEntry(dn, av)
      end

    else
      raise LDAP::ResultError::UnwillingToPerform, "OneLevel not implemented"
    end
  end

  def add(dn, av)
    raise LDAP::ResultError::UnwillingToPerform, "Read Only"
  end

  def del(dn)
    raise LDAP::ResultError::UnwillingToPerform, "Read Only"
  end

  def modify(dn, ops)
    raise LDAP::ResultError::UnwillingToPerform, "Read Only"
  end
end

# This is the shared object which carries our actual directory entries.
# It's just a hash of {dn=>entry}, where each entry is {attr=>[val,val,...]}
ChefAPI.configure do |config|
  config.endpoint = 'https://chef.example.org'
  config.client = 'seph'
  config.key    = '~/.chef/seph.pem'
end

connection = ChefAPI::Connection.new(
                                     endpoint: ENV['CHEF_URL'],
                                     client:   ENV['CHEF_CLIENT'],
                                     key:      ENV['CHEF_PEM']
                                     )
directory = {}
connection.search.query(:users, '*:*').rows.each do |dbitem|
  as_arrays = {}
  dbitem['raw_data'].each { |k,v| as_arrays[k] = Array(v) }
  id = dbitem['raw_data']['id']
  directory["cn=#{id},dc=example,dc=com"] = as_arrays
end



at_exit do
end

# Listen for incoming LDAP connections. For each one, create a Connection
# object, which will invoke a HashOperation object for each request.

s = LDAP::Server.new(
	:port			=> 1389,
	:nodelay		=> true,
	:listen			=> 10,
#	:ssl_key_file		=> "key.pem",
#	:ssl_cert_file		=> "cert.pem",
#	:ssl_on_connect		=> true,
	:operation_class	=> HashOperation,
	:operation_args		=> [directory]
)
s.run_tcpserver
s.join
