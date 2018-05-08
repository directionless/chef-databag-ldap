#!/usr/bin/env ruby

# borrowing from https://github.com/inscitiv/ruby-ldapserver/blob/master/examples

require 'ldap/server'
require 'json'

class DataBagOperation < LDAP::Server::Operation
  def initialize(connection, messageID, hash)
    super(connection, messageID)
    @databags = JSON.load(File.read('users.json')).values
    @hash = {
      "dc=example,dc=com" => {"cn"= > ["Top object"] },
      "cn=fred flintstone,dc=example,dc=com" => {
        "cn" => ["Fred Flintstone"],
        "sn" => ["Flintstone"],
        "mail" => ["fred@bedrock.org", "fred.flintstone@bedrock.org"]
      },
      "cn=wilma flintstone,dc=example,dc=com" => {
        "cn" => ["Wilma Flintstone"],
        "mail" => ["wilma@bedrock.org"]
      }
    }

  end

  

  
  # Handle searches of the form "(uid=<foo>)" using SQL backend
  # (uid=foo) => [:eq, "uid", matchobj, "foo"]

  def search(basedn, scope, deref, filter)
    #raise LDAP::ResultError::UnwillingToPerform, "Bad base DN" unless basedn == BASEDN
    #raise LDAP::ResultError::UnwillingToPerform, "Bad filter" unless filter[0..1] == [:eq, "uid"]
    uid = filter[3]
    @@pool.borrow do |sql|
      q = "select login_id,passwd from #{TABLE} where login='#{sql.quote(uid)}'"
      puts "SQL Query #{sql.object_id}: #{q}" if $debug
      res = sql.query(q)
      res.each do |login_id,passwd|
        @@cache.add(login_id, passwd)
        send_SearchResultEntry("id=#{login_id},#{BASEDN}", {
          "maildir"=>["/netapp/#{uid}/"],
        })
      end
    end
  end
end
