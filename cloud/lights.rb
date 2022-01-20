require_relative 'oschii'

include Oschii

DEFAULT_AMOUNT = 50
DEFAULT_FADE_TIME = 1000

name = ENV['OSCHII_NAME']
name = 'Edgar' if name.empty?

@oschii = cloud(silent: true).wait_for(name)

unless @oschii
  exit
end

@amounts = Hash.new(0)

def on(light, amount=DEFAULT_AMOUNT, fade_time=DEFAULT_FADE_TIME)
  @oschii.send_osc "/oschii/out#{light}", @amounts[light], amount, fade_time
  @amounts[light] = amount
end

def off(light, fade_time=DEFAULT_FADE_TIME)
  on(light, 0, fade_time)
end

def all_on(amount=DEFAULT_AMOUNT, fade_time=DEFAULT_FADE_TIME)
  12.times do |i|
    on(i, amount, fade_time)
    sleep 0.05
  end
end

def all_off(fade_time=DEFAULT_FADE_TIME)
  12.times do |i|
    off(i, fade_time)
    sleep 0.05
  end
end

puts %{
  Lighting Commands:

  - on      (light, amount=#{DEFAULT_AMOUNT}%, fade_time=#{DEFAULT_FADE_TIME}ms)
  - off     (light, fade_time=#{DEFAULT_FADE_TIME}ms)
  - all_on  (amount=#{DEFAULT_AMOUNT}%, fade_time=#{DEFAULT_FADE_TIME}ms)
  - all_off (fade_time=#{DEFAULT_FADE_TIME}ms)

}

