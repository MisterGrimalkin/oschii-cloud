require_relative 'oschii'

include Oschii

@oschii = cloud(silent: true).wait_for('ada')

exit unless @oschii


def norm(i)
  [[i, 100].min, 0].max
end

while true
  161.times do |i|
    red = norm i
    orange = norm i - 10
    yellow = norm i - 20
    green = norm i - 30
    blue = norm i - 40
    indigo = norm i - 50
    violet = norm i - 60

    args = [red, orange, yellow, green, blue, indigo, violet]
    @oschii.send_osc :rainbow, *args
    sleep 0.01
  end

  161.times do |j|
    i = 160 - j
    red = norm i - 60
    orange = norm i - 50
    yellow = norm i - 40
    green = norm i - 30
    blue = norm i - 20
    indigo = norm i - 10
    violet = norm i

    args = [red, orange, yellow, green, blue, indigo, violet]
    @oschii.send_osc :rainbow, *args
    sleep 0.01
  end
end
