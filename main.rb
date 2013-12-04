require 'rubygems'
require 'bundler/setup'
require 'logger'

require "active_record"

ActiveRecord::Base.establish_connection(
  adapter:  "sqlite3",
  database: ":memory:"
)


class Init < ActiveRecord::Migration
  def self.up
    create_table(:clients){|t|
      t.string :name
      t.integer :orders_count
      t.timestamps
      t.integer :lock_version
    }
    create_table(:orders){|t|
      t.references :client
      t.integer :price
      t.datetime :ordered_date
      t.timestamps
    }
    create_table(:addresses){|t|
      t.references :client
      t.string :pref
      t.integer :views
    }
  end
  def self.down
    drop_table :clients
    drop_table :orders
    drop_table :addresses
  end
end

class Client < ActiveRecord::Base
  has_one :address
  has_many :orders
end
class Address < ActiveRecord::Base
  belongs_to :client
end
class Order < ActiveRecord::Base
  belongs_to :client, :counter_cache => true
end

Init.migrate(:up)

Client.create({:name => "Alice"})
Client.create({:name => "Bob"})
Client.create({:name => "Carol"})
Address.create({:client => Client.find(1), :pref => "Osaka"})
Address.create({:client => Client.find(2), :pref => "Tokyo"})
Order.create({:client => Client.find(2), :price=> 20, :created_at => Time.now})
Order.create({:client => Client.find(2), :price=> 50, :created_at => 2.days.ago})
Order.create({:client => Client.find(3), :price=> 10, :created_at => 1.days.ago})
Order.create({:client => Client.find(3), :price=> 50, :created_at => 2.days.ago})
Order.create({:client => Client.find(3), :price=> 100,:created_at => 3.days.ago})


ActiveSupport::LogSubscriber.colorize_logging = false
ActiveRecord::Base.logger = Logger.new(STDOUT)

=begin
puts "## find"
p Client.find(1).name

puts "## first"
p Client.first.name

puts "## last"
p Client.last.name

p Client.find([1,2])

begin
  Client.find(100)
rescue ActiveRecord::RecordNotFound => e
  p e
end

begin
  Client.find([100])
rescue ActiveRecord::RecordNotFound => e
  p e
end

p Client.all

p Client.find_each {|c| }

Client.find_each(:include => :address) do |c|
  p c.address
end
Client.find_in_batches(:include => :address, :batch_size => 2) do |clients|
  p clients.size
end


p Client.where("1")
p Client.where("orders_count = '2'")
p Client.where("orders_count = '2'")



c = Client.select(:orders_count).first
begin
  p c.name
rescue ActiveModel::MissingAttributeError => e
  p e
end


p Client.group("date(created_at)")

p Order.select("date(created_at) as ordered_date, sum(price) as total_price")
  .group("date(created_at)")
  .having("sum(price) > ?", 10)

client = Client.readonly.first
client.name = "hoge"
client.save # raise ActiveRecord::ReadOnlyRecord


clients = Client.where("orders_count > 0")
p clients

clients = clients.except(:where)
p clients

c1 = Client.find(1)
c2 = Client.find(1)

c1.name = "Michael"
c1.save

c2.name = "should fail"
c2.save # Raises an ActiveRecord::StaleObjectError


Address.transaction do
  a = Address.lock.first
  a.pref = "Hokkaido"
  a.save
end
# begin transaction
# UPDATE "addresses" SET "pref" = 'Hokkaido' WHERE "addresses"."id" = 1
# commit transaction

Address.transaction do
  a = Address.lock("LOCK IN SHARE MODE").first
  a.increment!(:views)
end

a = Address.first
a.with_lock do
  # This block is called within a transaction,
  # item is already locked.
  a.increment!(:views)
end

=end

p Client.joins("LEFT OUTER JOIN addresses ON addresses.client_id = clients.id").where('addresses.pref'=> 'Osaka')
# SELECT "clients".* FROM "clients" LEFT OUTER JOIN addresses ON addresses.client_id = clients.id WHERE (addresses.pref = 'Osaka')
# [#<Client id: 1, name: "Alice", orders_count: nil, created_at: "2013-03-13 17:48:17", updated_at: "2013-03-13 17:48:17", lock_version: 0>]


p Client.joins(:address).where('addresses.pref' => 'Osaka') # has_oneで指定した通り
# SELECT "clients".* FROM "clients" INNER JOIN "addresses" ON "addresses"."client_id" = "clients"."id" WHERE "addresses"."pref" = 'Osaka'
# [#<Client id: 1, name: "Alice", orders_count: nil, created_at: "2013-03-13 18:29:50", updated_at: "2013-03-13 18:29:50", lock_version: 0>]


