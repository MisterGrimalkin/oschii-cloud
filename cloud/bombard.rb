require_relative 'oschii'

include Oschii

target_rate = ARGV[0]&.to_i || 100
wait_time = 1.0 / target_rate

oschii_name = ARGV[1] || 'Ada'
osc_address = ARGV[2] || 'tracker'

oschii = cloud(silent: true).wait_for(oschii_name)

exit unless oschii

value = 0
delta = 1
message_count = 0

start = Time.now

puts

begin
  while true
    oschii.send_osc osc_address, value
    message_count += 1

    sleep wait_time

    if value <= 0
      value = 0
      delta *= -1
    elsif value >= 100
      value = 100
      delta *= -1
    end
    value += delta

    print "\rSent messages: #{message_count}   Time: #{Time.now - start}    "
  end
rescue => e
  puts "ERROR:"
  puts e.class
end


