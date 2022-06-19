require 'json'
require 'osc-ruby'
require 'osc-ruby/em_server'

module LightSign
  class Device
    def initialize(ip, port: 3333)
      @ip = ip
      @port = port
    end

    # Uploaders....

    def update_from_file(filename = 'config/config.json')
      return unless File.exists? filename
      data = JSON.parse(File.read(filename))
      update data
    end

    def update(data)
      splash

      clear_events

      data['Events'].each do |day, events|
        events.each do |time, title|
          add_event day, time, title
        end
      end

      scroller *data.dig('Messages', 'Small')

      big_messages *data.dig('Messages', 'Large')
    end

    # Showers....

    def showers
      play 'Shower'
    end

    def female(ticket)
      replace_now 'Shower', 'FemaleTicket', ticket
    end

    def male(ticket)
      replace_now 'Shower', 'MaleTicket', ticket
    end

    def scroller(*messages)
      replace_now 'Shower', 'Scroller', *messages
    end

    # Events....

    def events
      play 'Events'
    end

    def clear_events
      clear 'Events', 'Day'
      clear 'Events', 'Time'
      clear 'Events', 'Title'
    end

    def add_event(day, time, title)
      add 'Events', 'Day', day
      add 'Events', 'Time', time
      add 'Events', 'Title', title
    end

    # Big Scroller....

    def big_scroller
      play 'BigScroller'
    end

    def clear_big_messages
      clear 'BigScroller', 'Scroller'
    end

    def big_messages(*messages)
      replace_now 'BigScroller', 'Scroller', *messages
    end

    # Splash....

    def splash
      play 'Splash'
    end

    # Holodeck....

    def holodeck
      play 'Holodeck'
    end

    # LightSign commands....

    def play(scene)
      command '/play', scene
    end

    def clear(scene, field)
      command '/message', scene, field, 'clear'
    end

    def next(scene, field)
      command '/message', scene, field, 'next'
    end

    def add(scene, field, *messages, now: false)
      command '/message', scene, field,
              (now ? 'add_now' : 'add'),
              *messages
    end

    def add_now(scene, field, *messages)
      add scene, field, *messages, now: true
    end

    def replace(scene, field, *messages, now: false)
      command '/message', scene, field,
              (now ? 'replace_now' : 'replace'),
              *messages
    end

    def replace_now(scene, field, *messages)
      replace scene, field, *messages, now: true
    end

    def command(address, *values)
      address = "/#{address}" unless address.start_with?('/')
      osc_client.send(
          OSC::Message.new(address, *values.to_a)
      )
      sleep 0.05
    end

    private

    def osc_client
      @osc_client ||= OSC::Client.new(@ip, @port)
    end
  end
end
