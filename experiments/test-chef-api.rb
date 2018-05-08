#!/usr/bin/env ruby

require 'rubygems'
require 'chef-api'
require 'json'
require 'pp'

ChefAPI.configure do |config|
  config.endpoint = 'https://chef.example.org'
  config.client = 'seph'
  config.key    = '~/.chef/seph.pem'
end

connection = ChefAPI::Connection.new(
  endpoint: 'https://chef.example.org',
  client:   'seph',
  key:      '~/.chef/seph.pem'
)

# databag stuff is way slower than raw search.
#connection.data_bags.fetch('users').items.each do |databag_user|
#  data = databag_user.to_hash
#end

USERS={}

connection.search.query(:users, '*:*').rows.each do |dbitem|
  u = dbitem['raw_data']
  USERS[u['id']] = u
end

puts JSON.pretty_generate(USERS)
