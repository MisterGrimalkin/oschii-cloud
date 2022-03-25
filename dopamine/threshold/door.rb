class Threshold
  class Door
    def initialize(number)
      @number = number

      @rgb_rest = [255, 255, 255]
      @rgb_play = [0, 0, 0]

      @w_rest = 0
      @w_play = 255

      @pwm_module = 'PWM-A'
      @mp3_player = 'MP3-A'

      @rgb_fade_to_play = 250
      @rgb_hold_play = 2000
      @rgb_fade_to_rest = 500

      @w_fade_to_play = 250
      @w_hold_play = 2000
      @w_fade_to_rest = 500
    end

    attr_accessor :number,
                  :rgb_rest, :rgb_play, :rgb_fade_to_play, :rgb_hold_play, :rgb_fade_to_rest,
                  :w_rest, :w_play, :w_fade_to_play, :w_hold_play, :w_fade_to_rest,
                  :pwm_module, :mp3_player

    def sensor
      {
          name: "beam#{number}",
          type: 'gpio',
          i2cModule: 'GPIO-A',
          pin: number,
          target: "Remote:/door#{number}",
          bounceFilter: 1000
      }
    end

    def drivers
      [
          {
              name: "door#{number}_front_R",
              initialValue: transform(rgb_rest[0]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 0
          },
          {
              name: "door#{number}_front_G",
              initialValue: transform(rgb_rest[1]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 1
          },
          {
              name: "door#{number}_front_B",
              initialValue: transform(rgb_rest[2]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 2
          },
          {
              name: "door#{number}_front_W",
              initialValue: transform(w_rest),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 3
          },
          {
              name: "door#{number}_back_R",
              initialValue: transform(rgb_rest[0]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 4
          },
          {
              name: "door#{number}_back_G",
              initialValue: transform(rgb_rest[1]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 5
          },
          {
              name: "door#{number}_back_B",
              initialValue: transform(rgb_rest[2]),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 6
          },
          {
              name: "door#{number}_back_W",
              initialValue: transform(w_rest),
              type: 'pwm',
              i2cModule: pwm_module,
              pin: 7
          }
      ]
    end

    def remote
      {
          address: "/door#{number}",
          writeTo: rgb_writer('R', 0) + rgb_writer('G', 1) + rgb_writer('B', 2) + w_writer + mp3_writer
      }
    end

    def rgb_writer(comp, index)
      [
          remote_writer(
              "door#{number}_front_#{comp}",
              from_amount: transform(rgb_rest[index]),
              to_amount: transform(rgb_play[index]),
              fade_in_time: rgb_fade_to_play,
              hold_time: rgb_hold_play,
              fade_out_time: rgb_fade_to_rest
          ),
          remote_writer(
              "door#{number}_back_#{comp}",
              from_amount: transform(rgb_rest[index]),
              to_amount: transform(rgb_play[index]),
              fade_in_time: rgb_fade_to_play,
              hold_time: rgb_hold_play,
              fade_out_time: rgb_fade_to_rest
          ),
      ]
    end

    def w_writer
      [
          remote_writer(
              "door#{number}_front_W",
              from_amount: transform(w_rest),
              to_amount: transform(w_play),
              fade_in_time: w_fade_to_play,
              hold_time: w_hold_play,
              fade_out_time: w_fade_to_rest
          ),
          remote_writer(
              "door#{number}_back_W",
              from_amount: transform(w_rest),
              to_amount: transform(w_play),
              fade_in_time: w_fade_to_play,
              hold_time: w_hold_play,
              fade_out_time: w_fade_to_rest
          )
      ]
    end

    def remote_writer(driver, from_amount:, to_amount:, fade_in_time:, hold_time:, fade_out_time:)
      {
          driver: driver,
          envelope: {
              steps: [
                  {
                      startAmount: from_amount,
                      endAmount: to_amount,
                      time: fade_in_time
                  },
                  {
                      amount: to_amount,
                      time: hold_time
                  },
                  {
                      startAmount: to_amount,
                      endAmount: from_amount,
                      time: fade_out_time
                  }
              ],
              stopAmount: from_amount
          }
      }
    end

    def mp3_writer
      [
          {
              target: "I2C:#{mp3_player}",
              message: [3]
          }
      ]
    end

    def transform(value)
      ((value.to_f / 255) * 4095).to_i
    end

    def inspect
      "#<Door#{number}:[#{rgb_rest.join(',')},#{w_rest}]->[#{rgb_play.join(',')},#{w_play}]>"
    end
  end
end