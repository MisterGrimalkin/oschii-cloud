require_relative 'device'
require 'restclient'
require 'osc-ruby'
require 'osc-ruby/em_server'

OSC_PORT = 3333
HTTP_PORT = 8001

SPLASH = '
  .       .   ,  __.
  |   * _ |_ -+-(__ * _ ._
  |___|(_][ ) | .__)|(_][ )
       ._|           ._|
          s e r v e r
'

module LightSign
  class Server
    CONFIG_LOCATION = LightSign::Device::CONFIG_LOCATION
    HTML_LOCATION = '/home/pi/light_sign/html'.freeze

    def initialize
      puts
      puts SPLASH
      puts

      @http_server = TCPServer.new HTTP_PORT
      @osc_server = OSC::EMServer.new OSC_PORT

      start_http_server
      start_osc_server

      @bootstrap_min_css = File.read("#{HTML_LOCATION}/lib/bootstrap.min.css")
      @jquery_min_js = File.read("#{HTML_LOCATION}/lib/jquery.min.js")
      @bootstrap_min_js = File.read("#{HTML_LOCATION}/lib/bootstrap.min.js")

      puts
      puts "+++ Server Online: #{local_ip_address} +++"
      puts

      @devices = {}

      osc '/checkin' do |message|
        name = message.to_a.first.split(':')[1].to_sym
        devices[name] ||= Device.new(name, message.ip_address)
        puts "#{Time.now} Checkin from '#{name}' on #{message.ip_address}"
        devices[name].update_from_file
        push_shower_tickets
      end

      # System...

      post '/snapper/trigger' do
        trigger_snapper
        [201, "Snap!\n", 'text/plain']
      end

      post '/snapper/preview_mode' do
        [201, preview_mode, 'text/plain']
      end

      post '/snapper/slide_mode' do
        [201, slide_mode, 'text/plain']
      end

      post '/snapper/camera' do |payload|
        send_camera_command(payload)
        [201, "OK\n", 'text/plain']
      end

      get '/snapper/camera/settings' do
        [200, camera_settings, 'text/plain']
      end


      # UI....

      get '/' do
        [200, read_html_file('index.html'), 'text/html']
      end

      get '/showers' do
        [200, read_html_file('showers.html'), 'text/html']
      end

      get '/messages' do
        [200, read_html_file('messages.html'), 'text/html']
      end

      get '/scenes' do
        [200, read_html_file('scenes.html'), 'text/html']
      end

      get '/devices' do
        [200, read_html_file('devices.html'), 'text/html']
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

      post '/api/ping' do
        @devices = {}

        Thread.new do
          ping_network
        end
      end

      get '/api/devices' do
        result = []
        devices.each do |_name, device|
          result << {
              name: device.name,
              ip: device.ip
          }
        end
        # result << {
        #     name: 'Bill',
        #     ip: '2.0.0.123'
        # }
        # result << {
        #     name: 'Bob',
        #     ip: '2.0.0.138'
        # }
        [200, result.to_json, 'application/json']
      end

      get '/api/config' do
        [200, JSON.pretty_generate(read_config_file('config.json')), 'text/plain']
      end

      post '/api/config' do |payload|
        begin
          data = JSON.parse(payload)
          File.write("#{CONFIG_LOCATION}/config.json", JSON.pretty_generate(data))
          Thread.new do
            update_all_devices
          end
          [200, 'OK']

        rescue JSON::ParserError => e
          [422, e.message, 'text/plain']
        end
      end

      get '/api/showers' do
        [200, JSON.pretty_generate(read_config_file('showers.json')), 'application/json']
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

      get '/lib/bootstrap.min.css' do
        @bootstrap_min_css ||= File.read("#{HTML_LOCATION}/lib/bootstrap.min.css")
        [200, @bootstrap_min_css, 'text/css']
      end

      get '/lib/jquery.min.js' do
        @jquery_min_js ||= File.read("#{HTML_LOCATION}/lib/jquery.min.js")
        [200, @jquery_min_js, 'application/javascript']
      end

      get '/lib/bootstrap.min.js' do
        @bootstrap_min_js ||= File.read("#{HTML_LOCATION}/lib/bootstrap.min.js")
        [200, @bootstrap_min_js, 'application/javascript']
      end
    end

    def preview_mode
      `/home/pi/snapper/modepreview.sh`
    end

    def slide_mode
      `/home/pi/snapper/modeslide.sh`
    end

    def send_camera_command(command)
      client = OSC::Client.new(local_ip_address, 5432)
      client.send(OSC::Message.new('/camera', command))
    end

    def trigger_snapper
      client = OSC::Client.new(local_ip_address, 5432)
      client.send(OSC::Message.new('/trigger', 1))
    end

    def camera_settings
      File.read('/home/pi/snapper/picamera.ini')
    end

    def read_config_file(filename)
      JSON.parse(File.read("#{CONFIG_LOCATION}/#{filename}"))
    end

    def read_html_file(filename)
      File.read("#{HTML_LOCATION}/#{filename}")
    end

    attr_reader :devices, :http_server, :osc_server

    def shower_tickets
      read_config_file('showers.json')
    end

    def push_shower_tickets
      puts "#{Time.now} Sending shower tickets...."
      tickets = shower_tickets
      devices.each do |_name, device|
        device.female tickets['female'].to_s
        device.male tickets['male'].to_s
      end
      puts "#{Time.now} Shower tickets updated"
    end

    def update_shower_tickets(data)
      puts 'Updating shower tickets'
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
      File.write("#{CONFIG_LOCATION}/showers.json", JSON.pretty_generate(data))
    end

    def update_all_devices
      puts 'Updating all devices'
      devices.each do |name, device|
        device.update_from_file
      end
    end

    def ping_network
      puts 'Scanning network'
      base_ip = local_ip_address.split('.')[0..2].join('.')
      (1..254).each do |i|
        target_ip = "#{base_ip}.#{i}"
        client = OSC::Client.new(target_ip, OSC_PORT)
        client.send(OSC::Message.new('/ping', 1))
        sleep 0.001
      end
    end

    def local_ip_address
      # until (addr = Socket.ip_address_list.detect { |intf| intf.ipv4_private? })
      # end
      # addr.ip_address
      `hostname -I`.split[0]
    end

    def http_handlers
      @http_handlers ||= {
          post: {}, get: {}, put: {}
      }
    end

    def osc(address)
      osc_server.add_method address do |message|
        puts 'Receive OSC'
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
          begin

            # puts 'HTTP Waiting for data'

            client = http_server.accept
            # puts 'Got data'

            remote_ip = client.peeraddr[2]
            # puts remote_ip

            line = ""
            until (char = client.read(1)) == "\n"
              line << char
            end

            # puts line
            method, path, _ = line.split
            headers = {}

            done = false

            until done do
              line = client.gets
              # puts line
              if line == "\r\n"
                done = true
              else
                key, value = line.split(': ')
                headers[key] = value
              end
            end

            # puts 'Parsed data'

            payload = client.read(headers['Content-Length'].to_i)

            # puts payload

            if (block = http_handlers[method.downcase.to_sym][path])
              puts "#{Time.now} HTTP #{method} #{path} from #{remote_ip}"
              status, body, content_type = block.call(payload)
            else
              # if (content = find_public_file(path))
              #   puts "#{Time.now} HTTP Public file #{path}"
              #   status, body, content_type = 200, content, 'text/plain'
              # else
                puts "#{Time.now} HTTP #{method} #{path} NOT FOUND"
                status, body, content_type = 404, 'Not Found', 'text/plain'
              # end
            end

            # puts 'Writing to client'
            client.puts "HTTP/1.1 #{status}\r\nContent-Type: #{content_type}\r\n\r\n#{body}\r\n"

              # puts 'Closing connection'
              # client.close
              #
              # puts 'All Done'

          rescue => e
            puts "#{e.class} #{e.message}"
            puts "#{e.backtrace.join("\n")}"
            client.puts "HTTP/1.1 500\r\n\r\n#{e.message}\r\n"
          ensure
            client.close
          end
        end
      end
      puts "   HTTP: #{HTTP_PORT}"
    end

    def find_public_file(path)
      filename = "#{HTML_LOCATION}/public#{path}"

      return nil unless File.exists? filename

      File.read(filename)
    end
  end

end

