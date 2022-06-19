require_relative 'device'
require 'restclient'
require 'osc-ruby'
require 'osc-ruby/em_server'

OSC_PORT = 3333
HTTP_PORT = 8000

SPLASH = '
  .       .   ,  __.
  |   * _ |_ -+-(__ * _ ._
  |___|(_][ ) | .__)|(_][ )
       ._|           ._|
          s e r v e r
'

module LightSign
  class Server
    def initialize
      puts
      puts SPLASH
      puts
      puts "  #{local_ip_address}"
      puts

      start_http_server
      start_osc_server

      puts

      @devices = {}

      osc '/checkin' do |message|
        name = message.to_a.first.split(':')[1].to_sym
        devices[name] ||= Device.new(message.ip_address)
        puts "#{name} checked in from #{message.ip_address}"
        update_all_devices
        push_shower_tickets
      end

      # UI....

      get '/showers' do
        [200, File.read('html/showers.html')]
      end

      get '/messages' do
        [200, File.read('html/messages.html')]
      end

      get '/scenes' do
        [200, File.read('html/scenes.html')]
      end

      # Scenes....

      post '/scene/showers' do
        devices.each do |_name, device|
          device.showers
        end
      end

      post '/scene/events' do
        devices.each do |_name, device|
          device.events
        end
      end

      post '/scene/big_scroller' do
        devices.each do |_name, device|
          device.big_scroller
        end
      end

      post '/scene/holodeck' do
        devices.each do |_name, device|
          device.holodeck
        end
      end

      # API....

      get '/api/config' do
        [200, File.read('config/config.json')]
      end

      post '/api/config' do |payload|
        begin
          data = JSON.parse(payload)
          File.write('config/config.json', JSON.pretty_generate(data))
          update_all_devices
          [200, 'OK']

        rescue JSON::ParserError => e
          [422, e.message]
        end
      end

      get '/api/showers' do
        [200, File.read('config/showers.json')]
      end

      post '/api/male' do |payload|
        devices.each do |_name, device|
          device.male payload.to_s
        end
        update_shower_tickets male: payload.to_i
        [200, payload]
      end

      post '/api/female' do |payload|
        devices.each do |_name, device|
          device.female payload.to_s
        end
        update_shower_tickets female: payload.to_i
        [200, payload]
      end

      post '/api/refresh' do
        update_all_devices
        push_shower_tickets
      end

      ping_network
    end

    attr_reader :devices

    def shower_tickets
      JSON.parse(File.read('config/showers.json'))
    end

    def push_shower_tickets
      tickets = shower_tickets
      devices.each do |_name, device|
        device.female tickets['female'].to_s
        device.male tickets['male'].to_s
      end
    end

    def update_shower_tickets(data)
      tickets = shower_tickets
      if data[:male]
        tickets['male'] = data[:male]
      end
      if data[:female]
        tickets['female'] = data[:female]
      end
      save_shower_tickets tickets
    end

    def save_shower_tickets(data)
      File.write('config/showers.json', JSON.pretty_generate(data))
    end

    def update_all_devices
      devices.each do |name, device|
        puts "Updating #{name}"
        device.update_from_file
      end
    end

    def ping_network
      base_ip = local_ip_address.split('.')[0..2].join('.')
      (1..254).each do |i|
        target_ip = "#{base_ip}.#{i}"
        client = OSC::Client.new(target_ip, OSC_PORT)
        client.send(OSC::Message.new('/ping', 1))
        sleep 0.001
      end
    end

    def local_ip_address
      until (addr = Socket.ip_address_list.detect { |intf| intf.ipv4_private? })
      end
      addr.ip_address
    end

    def http_handlers
      @http_handlers ||= {
          post: {}, get: {}, put: {}
      }
    end

    def osc(address)
      osc_server.add_method address do |message|
        if block_given?
          yield message
        else
          puts "--> OSC #{address} [ #{message.to_a.join(' ')} ]"
        end
      end
    end

    def http(method, path, &block)
      unless block_given?
        block = ->(payload) { puts "--> HTTP #{method.to_s.upcase} #{path} [ #{payload} ]" }
      end
      method_key = method.to_s.downcase.to_sym
      http_handlers[method_key][path] = block
    end

    def get(path, &block)
      http :get, path, &block
    end

    def post(path, &block)
      http :post, path, &block
    end

    def put(path, &block)
      http :put, path, &block
    end

    def start_osc_server
      Thread.new do
        osc_server.run
      end
      puts "    OSC: #{OSC_PORT}"
    end

    def start_http_server
      Thread.new do
        loop do
          client = http_server.accept
          line = client.gets
          # put client.ip
          method, path, _ = line.split
          headers = {}

          done = false

          until done do
            line = client.gets
            if line == "\r\n"
              done = true
            else
              key, value = line.split(': ')
              headers[key] = value
            end
          end

          payload = client.read(headers['Content-Length'].to_i)


          if (block = http_handlers[method.downcase.to_sym][path])
            status, body = block.call(payload)
          else
            status, body = 404, 'Not Found'
          end

          client.puts "HTTP/1.1 #{status}\r\n\r\n#{body}"
          client.close
        end
      end
      puts "   HTTP: #{HTTP_PORT}"
    end

    def osc_server
      @osc_server ||= OSC::EMServer.new(OSC_PORT)
    end

    def http_server
      @http_server ||= TCPServer.new HTTP_PORT
    end
  end
end

