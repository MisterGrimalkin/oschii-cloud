require_relative 'server'

def server
  @server ||= LightSign::Server.new
end

server

puts
puts '+++ Server is online +++'
puts

server.ping_network

loop do

end