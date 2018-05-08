require 'benchmark'
require 'ridley'

ridley = Ridley.new(
                    server_url: 'https://chef.example.org',
                    client_name: 'seph',
                    client_key: '~/.chef/seph.pem'
                    )
users = {}

ridley.search(:users, '*:*').each do |dbitem|
  u = dbitem['raw_data']
  users[u['id']] = u
end

