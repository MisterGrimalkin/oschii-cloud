require 'restclient'
require 'rubyserial'
require 'json'
require 'io/console'
require 'faye/websocket'
require 'eventmachine'
require 'byebug'

module Oschii
  class Node
    BAUD_RATE = 115200

    NodeUnavailableError = Class.new(StandardError)
    CancelSerialQuery = Class.new(StandardError)

    def initialize(ip: nil, serial: nil)
      raise NodeUnavailableError, 'No connection method specified' if ip.nil? && serial.nil?

      @ip_address = ip
      @serial = serial
      @capturing_serial = false
      @serial_lines = []
      @web_socket_lines = []
      @osc_clients = {}

      poke!
    end

    attr_reader :ip_address, :serial, :serial_lines, :name, :version,
                :log_socket, :web_socket_lines, :osc_clients

    def refresh
      stop_web_socket
      @name = nil
      @version = nil
      poke!
    end

    def poke!
      remaining_attempts = 3
      while remaining_attempts > 0
        begin
          return self if poke
        rescue RubySerial::Error => e
          raise NodeUnavailableError, case e.message
                                        when 'ENOENT'
                                          '(no device)'
                                        when 'EBUSY'
                                          '(port in use)'
                                        else
                                          e.message
                                      end
        rescue RestClient::Exception => e
          raise NodeUnavailableError, e.message
        end
        remaining_attempts -= 1
      end
      raise NodeUnavailableError, 'Oschii did not respond'
    end

    def poke
      if serial?
        start_serial_capture
        response = serial_query('poke', timeout: 2)
        return response == 'Tickles!'
      else
        name
        begin
          start_web_socket
        rescue
          # ignored
        end
        return true
      end
      false
    end

    def version
      @version ||= if serial?
                     serial_query 'version'
                   else
                     RestClient.get("http://#{ip}/version")&.body
                   end
    end

    def tail(filter: nil)
      logs = serial? ? serial_lines : web_socket_lines
      while true
        while (line = logs.shift)
          if filter.nil? || line.match?(filter)
            puts line
          end
        end
        sleep 0.05
      end
    end

    def ip
      if serial?
        serial_query 'ip'
      else
        ip_address
      end
    end

    def restart
      if serial?
        serial_query 'restart'
      else
        RestClient.post("http://#{ip}/restart", {})&.body
      end
    end

    def name
      @name ||= if serial?
                  serial_query 'name'
                else
                  RestClient.get("http://#{ip}/name")&.body
                end
    end

    def name=(new_name)
      if serial?
        puts 'Querying serial port....'
        if serial_query('name=') == '>> Enter new name <<'
          puts serial_query new_name
        end
      else
        RestClient.post("http://#{ip}/name", new_name)&.body
      end
      refresh
    end

    def update_config(new_config = nil, file: nil)
      unless file.nil?
        puts 'Reading file....'
        new_config = JSON.parse(File.read(file))
      end
      if serial?
        puts 'Querying serial port....'
        if serial_query('config=') == '>> Enter new configuration <<'
          puts 'Uploading configuration....'
          puts serial_query new_config.to_json
        end
      else
        RestClient.post(
            "http://#{ip}/config",
            JSON.pretty_generate(new_config),
            content_type: 'application/json'
        )
      end
      refresh
    end

    def config
      JSON.parse raw_config
    end

    def sensors
      config['sensors'].map { |s| s['name'] }
    end

    def sensor(name)
      config['sensors'].select { |s| s['name']==name }.first
    end

    def drivers
      config['drivers'].map { |d| d['name'] }
    end

    def driver(name)
      config['drivers'].select { |d| d['name']==name }.first
    end

    def remotes
      config['driverRemotes'].map { |r| r['address'] }
    end

    def remote(address)
      config['driverRemotes'].select { |r| r['address']==address || r['address']=="/#{address}" }.first
    end

    def monitors
      config['sensorMonitors'].map { |m| "sensor:#{m['sensor']}" }
    end

    def monitor(sensor_name)
      mons = config['sensorMonitors'].select { |m| m['sensor'] == sensor_name }
      mons.size==1 ? mons[0] : mons
    end

    def receivers
      config['receivers'].map { |r| r['name'] }
    end

    def receiver(name)
      config['receivers'].select { |r| r['name']==name }.first
    end

    def i2c
      config['i2c']
    end

    def i2c_modules
      i2c['modules'].map { |m| m['name'] }
    end

    def i2c_module(name)
      i2c['modules'].select { |m| m['name']==name }.first
    end

    def raw_config
      if serial?
        serial_query 'config', timeout: 3
      else
        RestClient.get("http://#{ip}/config.json")&.body
      end
    end

    def update_settings(new_settings = nil, file: nil)
      unless file.nil?
        puts 'Reading file....'
        new_settings = JSON.parse(File.read(file))
      end
      if serial?
        puts 'Querying serial port....'
        if serial_query('settings=') == '>> Enter new settings <<'
          puts 'Uploading settings....'
          puts serial_query new_settings.to_json
        end
      else
        RestClient.post("http://#{ip}/settings", new_settings.to_json, content_type: 'application/json')
      end
      refresh
    end

    def settings
      JSON.parse raw_settings
    end

    def raw_settings
      if serial?
        serial_query 'settings'
      else
        RestClient.get("http://#{ip}/settings.json")&.body
      end
    end

    def start_wifi(ssid = nil, password = nil)
      return 'Not available over network' unless serial?

      begin
        if ssid.nil?
          ssid = prompt 'Enter SSID'
        end

        if password.nil?
          password = prompt 'Enter password', obscure: true
        end

        puts 'Querying serial port...'
        if serial_query('start wifi') == '>> Enter new Wifi SSID <<'
          puts 'Sending SSID...'
          if serial_query(ssid) == '>> Enter new Wifi Password <<'
            puts 'Sending password...'
            puts serial_query(password)
          end
        end

      rescue CancelSerialQuery
        puts 'Cancelled'
      end
    end

    def stop_wifi
      return 'Not available over network' unless serial?

      serial_query 'stop wifi'
    end

    def start_ethernet
      return 'Not available over network' unless serial?

      serial_query 'start ethernet'
    end

    def stop_ethernet
      return 'Not available over network' unless serial?

      serial_query 'stop ethernet'
    end

    def start_web_socket
      EM.run {
        @log_socket = Faye::WebSocket::Client.new("ws://#{ip}/logger_ws")

        log_socket.on :open do |event|
          log_socket.send('WebSocket connected')
        end

        log_socket.on :message do |event|
          event.data.split("\n").each do |line|
            web_socket_lines << line
          end
        end

        log_socket.on :close do |event|
          log_socket.send("WebSocket DISCONNECTED: #{event.code} #{event.reason}")
          @log_socket = nil
        end
      }
    end

    def stop_web_socket
      log_socket.close
    end

    # Serial

    def serial?
      !serial.nil?
    end

    def serial_query(query, timeout: 3)
      purge_serial
      serial_port.write (query.empty? ? "\n" : query)
      sleep timeout
      result = serial_lines.join
      serial_lines.clear
      result
    end

    def purge_serial
      serial_lines.clear
      self.serial_line_buffer = ''
    end

    def start_serial_capture
      return if capturing_serial

      Thread.new do
        self.capturing_serial = true
        self.serial_line_buffer = ''
        serial_lines.clear
        while capturing_serial
          input = serial_port.read 100
          input.each_char do |c|
            if c == "\n"
              serial_lines << serial_line_buffer.gsub("\r", '')
              self.serial_line_buffer = ''
            else
              serial_line_buffer << c
            end
          end
          sleep 0.01
        end
      end
    end

    def stop_serial_capture
      self.capturing_serial = false
    end

    def self.find_serial(port = nil)
      return Node.new(serial: port) if port

      puts 'Scanning serial ports....'

      nodes = []

      9.times do |i|
        port = "/dev/ttyUSB#{i}"
        print "#{port}   "
        begin
          node = Node.new(serial: port)
          puts "Oschii - #{node.name}"
          nodes << node
        rescue NodeUnavailableError => e
          puts e.message
        end
      end

      nodes
    end

    def logger(sensors: nil, drivers: nil,
               monitors: nil, remotes: nil,
               all: nil, to_file: nil)
      current_logger = settings['logger']
      unless all.nil?
        sensors = all
        drivers = all
        monitors = all
        remotes = all
      end
      current_logger['sensors'] = sensors unless sensors.nil?
      current_logger['drivers'] = drivers unless drivers.nil?
      current_logger['monitors'] = monitors unless monitors.nil?
      current_logger['remotes'] = remotes unless remotes.nil?
      current_logger['logToFile'] = to_file unless to_file.nil?
      update_settings({'logger' => current_logger})
      current_logger = settings['logger']
      puts JSON.pretty_generate current_logger
    end

    def inspect
      "<#{self.class.name}[#{name}] #{serial? ? serial : ip_address} (v#{version})>"
    end

    def send_osc(address, *values, port: 3333)
      address = "/#{address}" unless address[0] == '/'
      osc_client(port).send(OSC::Message.new(address, *values))
    end

    def osc_client(port)
      osc_clients[port] ||= OSC::Client.new(ip, port)
    end

    def send_http(path, value = 1, method: :post)
      path = "/#{path}" unless %w(/ :).include?(path[0])
      method = method.to_s.downcase.to_sym
      url = "http://#{ip}#{path}"
      if method == :get
        args = [url]
      else
        args = [url, value.to_s]
      end
      puts RestClient.send(method, *args)
    rescue RestClient::BadRequest => e
      puts "Oschii didn't like that: #{e.http_body}"
    end

    def log
      if serial?
        serial_query 'print log'
      else
        RestClient.get("http://#{ip}/log")&.body
      end
    end

    def clear_log
      if serial?
        serial_query 'clear log'
      else
        RestClient.delete("http://#{ip}/log")&.body
      end
    end

    private

    attr_accessor :capturing_serial, :serial_line_buffer

    def prompt(text, obscure: false)
      print "#{text}: "
      input = ''
      char = ''
      until !char.empty? && char.ord == 13
        char = STDIN.getch
        if char.ord == 127
          # BACKSPACE
          input = input[0..-2]
          print "\r#{text}: #{' ' * input.size} "
          print "\r#{text}: #{obscure ? '*' * input.size : input}"
        elsif char.ord == 27
          # ESC
          raise CancelSerialQuery
        elsif char.ord == 13
          # ENTER
        else
          input += char
          if obscure
            print '*'
          else
            print char
          end
        end
      end
      puts
      input
    end

    def serial_port
      @serial_port ||= Serial.new serial, BAUD_RATE if serial?
    end
  end
end