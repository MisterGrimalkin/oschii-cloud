require_relative 'oschii'

include Oschii

oschii_name = ARGV[0]

unless oschii_name
  puts 'Specify Oschii name'
  exit 1
end

oschii = cloud(silent: true).wait_for(oschii_name)

return unless oschii

values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 90]
deltas = [1] * 12

while true
  values.size.times do |i|
    v = values[i]
    d = deltas[i]
    v += d
    if v >= 100
      v = 100
      d = -1 * d
    end
    if v <= 0
      v = 0
      d = -1 * d
    end
    values[i] = v
    deltas[i] = d
  end
  oschii.send_osc :pwm, *values

  sleep 0.01
end