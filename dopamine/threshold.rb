require_relative 'threshold/door.rb'

class Threshold
  def initialize
    @doors = [
        Door.new(0),
        Door.new(1),
        Door.new(2),
        Door.new(3)
    ]

    doors[0].rgb_rest = [255, 64, 64]
    doors[0].rgb_play = [0, 0, 0]
    doors[0].w_rest = 0
    doors[0].w_play = 255
    doors[0].pwm_module = 'PWM-A'
    doors[0].mp3_player = 'MP3-A'

    doors[1].rgb_rest = [64, 255, 64]
    doors[1].rgb_play = [0, 0, 0]
    doors[1].w_rest = 0
    doors[1].w_play = 255
    doors[1].pwm_module = 'PWM-B'
    doors[1].mp3_player = 'MP3-B'

    doors[2].rgb_rest = [64, 64, 255]
    doors[2].rgb_play = [0, 0, 0]
    doors[2].w_rest = 0
    doors[2].w_play = 255
    doors[2].pwm_module = 'PWM-C'
    doors[2].mp3_player = 'MP3-C'

    doors[3].rgb_rest = [255, 255, 64]
    doors[3].rgb_play = [0, 0, 0]
    doors[3].w_rest = 0
    doors[3].w_play = 255
    doors[3].pwm_module = 'PWM-D'
    doors[3].mp3_player = 'MP3-D'
  end

  def config
    {
        name: 'Dopamine Threshold',
        description: 'Dawes to Nowhere',
        i2c: {
            sdaPin: 4,
            sclPin: 5,
            clock: 1000000,
            modules: [
                {
                    name: 'GPIO-A',
                    type: 'gpio',
                    address: '0x20'
                },
                {
                    name: 'PWM-A',
                    type: 'pwm',
                    address: '0x40'
                },
                {
                    name: 'PWM-B',
                    type: 'pwm',
                    address: '0x41'
                },
                {
                    name: 'PWM-C',
                    type: 'pwm',
                    address: '0x42'
                },
                {
                    name: 'PWM-D',
                    type: 'pwm',
                    address: '0x43'
                },
                {
                    name: 'MP3-A',
                    type: 'mp3',
                    address: '0x36'
                },
                {
                    name: 'MP3-B',
                    type: 'mp3',
                    address: '0x37'
                },
                {
                    name: 'MP3-C',
                    type: 'mp3',
                    address: '0x38'
                },
                {
                    name: 'MP3-D',
                    type: 'mp3',
                    address: '0x39'
                }
            ]
        },
        sensors: doors.map(&:sensor),
        drivers: doors.map(&:drivers).flatten,
        remotes: doors.map(&:remote)
    }

  end

  attr_reader :doors

  def to_json
    JSON.pretty_generate config
  end

  def save(filename)
    File.write(filename, to_json)
  end

  def inspect
    "#<DopamineThreshold #{doors}>"
  end
end