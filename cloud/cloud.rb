require 'restclient'
require 'osc-ruby'
require 'osc-ruby/em_server'
require 'socket'

module Oschii
  class Cloud

    PING_PORT = 3333
    PING_ADDR = '/hello_oschii'
    RESPONSE_PORT = 3333
    RESPONSE_ADDR = '/i_am_oschii'

    def initialize(silent: false)
      @server = OSC::EMServer.new(RESPONSE_PORT)
      @nodes = {}
      @silent = silent
      start_listening

      @http_handlers = {
          post: {}, get: {}, put: {}
      }

    end

    attr_reader :server, :http_handlers, :nodes, :silent

    def find_serial(port = nil)
      return Node.new(serial: port) if port

      puts "\n~~> Scanning Serial Ports...."

      9.times do |i|
        port = "/dev/ttyUSB#{i}"
        print "\n~~> #{port}: "
        begin
          node = Node.new(serial: port)
          name = "serial_#{node.name.downcase}".to_sym
          if (existing_node = nodes[name.downcase.to_sym])
            existing_node.refresh
          else
            nodes[name] = node
            node.refresh
          end
          puts "'#{node.name}'"
        rescue ::Oschii::NodeUnavailableError => e
          puts e.message
        end
      end

      print_nodes

      self
    end

    def start_listening
      server.add_method RESPONSE_ADDR do |message|
        name = message.to_a.first.split(':').last.strip
        if (node = nodes[name.downcase.to_sym])
          puts "\n==> '#{name}' is back\n" unless silent
          node.refresh
        else
          node = Node.new(ip: message.ip_address)
          puts "\n==> '#{name}' connected @ #{node.ip_address}\n" unless silent
          nodes[name.downcase.to_sym] = node
        end
      end
      Thread.new do
        server.run
      end
      Thread.new do
        http_server = TCPServer.new 8000
        session = http_server.accept
        while true do
          method = nil
          path = nil
          value = nil
          while (request = session.gets&.chomp) do
            unless method && path
              method, path = request.split ' '
            end
            value = request
            session.puts "HTTP/1.1 200 OK\n\n"
          end
          if (block = http_handlers[method.downcase.to_sym][path])
            block.call value
          end
          session.close
          session = http_server.accept
        end
      end
    end

    def wait_for(oschii_name, timeout: 10)
      print "==> Waiting for '#{oschii_name}'.... "
      find_nodes
      oschii = nil
      started = Time.now
      while oschii.nil? && Time.now - started <= timeout
        oschii = get oschii_name
      end
      if oschii
        puts 'FOUND :D'
      else
        puts 'NOT FOUND :('
      end
      oschii
    end

    attr_reader :monitor

    def monitor_osc(*address_list, max: 100)
      @monitor ||= OscMonitor.new self

      address_list = [address_list] unless address_list.is_a?(Array)

      address_list.each do |address|
        monitor.add address, max: max
      end

      monitor.run
    end

    def capture_osc(address, simple: true, &block)
      if address[0] == '/'
        actual_address = address
      else
        actual_address = "/#{address}"
      end
      server.add_method actual_address do |message|
        value = simple ? message.to_a.first&.to_i : JSON.parse(message.to_a.first)
        if block_given?
          yield value
        else
          puts "--> OSC #{address} [ #{value} ]"
        end
      end
    end

    def capture_http(path, method: :post, &block)
      actual_path = "/#{path}" unless path[0] == '/'
      unless block_given?
        block = ->(value) { puts "--> HTTP #{method.to_s.upcase} #{actual_path} [ #{value} ]" }
      end
      http_handlers[method.to_s.downcase.to_sym][actual_path] = block
    end

    def find_nodes
      @nodes = {}
      base_ip = local_ip_address.split('.')[0..2].join('.')
      (1..254).each do |i|
        target_ip = "#{base_ip}.#{i}"
        client = OSC::Client.new(target_ip, PING_PORT)
        client.send(OSC::Message.new(PING_ADDR, 1))
        sleep 0.001
      end
    end

    def populate
      puts '==> Scanning Network....' unless silent
      find_nodes
      start_waiting = Time.now
      while Time.now - start_waiting < 3
        sleep 0.2
      end

      print_nodes unless silent
      self
    end

    def print_nodes
      puts
      puts self.to_s
      puts
      puts
    end

    def to_s
      return '' if nodes.empty?

      result = ''

      conn_width = 0
      name_width = 0
      nodes.each do |name, node|
        if node.serial?
          conn_width = node.serial_port.size if node.serial_port.size > conn_width
        else
          conn_width = node.ip.size if node.ip.size > conn_width
        end
        name_width = name.size if name.size > name_width
      end

      sorted = nodes.to_a.sort_by { |name, _node| name }.to_h

      result += "\e[1m#{'Name'.ljust(name_width+3)}#{'Connection'.ljust(conn_width+3)}#{'Version'}\e[22m"
      sorted.each do |_name, node|
        connection = if node.serial?
                       node.serial.ljust(conn_width)
                     else
                       node.ip.ljust(conn_width)
                     end
        result += "\n#{node.name.ljust(name_width)}   #{connection}   #{node.version}"
      end
      result += "\n"
      result
    end

    def get(name)
      nodes[name.to_s.downcase.to_sym]
    end

    def inspect
      "<#{self.class.name} #{local_ip_address} nodes: #{nodes.size}>"
    end

    def local_ip_address
      # until (addr = Socket.ip_address_list.detect { |intf| intf.ipv4_private? })
      # end
      # addr.ip_address
      `hostname -I`.split[0]
    end
  end
end