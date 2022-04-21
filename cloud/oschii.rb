require_relative 'node'
require_relative 'cloud'
require_relative 'osc_monitor'

module Oschii
  LOGO = '
  ╔═╗┌─┐┌─┐┬ ┬┬┬
  ║ ║└─┐│  ├─┤││
  ╚═╝└─┘└─┘┴ ┴┴┴
    C L O U D
  '
  def self.included(base)
    base.class_eval do
      puts LOGO
    end
  end

  def cloud(silent: false)
    @cloud ||= Cloud.new(silent: silent)
  end

  def populate
    cloud.populate
  end

  def serial
    @serial ||= cloud.find_serial
  end

  def method_missing(m, *args, &block)
    return if @cloud.nil?

    node = cloud.get(m)

    return node unless node.nil?

    raise NameError
  end

  def send_osc(ip, address, value, port: 3333)
    OSC::Client.new(ip, port).send(OSC::Message.new(address, value))
  end
end

unless ENV['CONNECT'].nil?
  include Oschii
  populate
end

