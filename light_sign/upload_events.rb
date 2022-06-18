require_relative 'device'
require 'json'

ip = ARGV[0]

if ip.nil?
  puts 'Must provide: <IP>'
  exit 1
end

sign = LightSign::Device.new(ip)
sign.update_from_file
