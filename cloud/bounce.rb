require_relative 'oschii'

include Oschii

# @oschii = cloud(silent: true).wait_for('ada')
#
# exit unless @oschii

@board = []

@osc = OSC::Client.new('192.168.1.22', 3333)

@width = 1
@height = 1

def clear_board
  @height.times do |y|
    @board[y] = []
    @width.times do |x|
      @board[y] << '-'
    end
  end
end

def print_board
  message = []
  @height.times do |y|
    @width.times do |x|
      # print "#{@board[y][x]} "
      if @board[y][x] == '#'
        print "\r#{x} x #{y}        "
        message += [255, 255, 255]
      else
        message += [0, 0, 0]
      end
    end
    # puts
  end
  # puts message.join(',')
  @osc.send(OSC::Message.new('/display', *message[0..128]))
  # Thread.new do

  # RestClient.post 'http://192.168.1.22/display',
  #                 message.to_json,
  #                 content_type: 'application/json'
  # end

  # ada.send_osc :display, *message
end

clear_board

@ball_x = 58
@ball_y = 11

@dx = 1
@dy = 1

def update_board
  # clear_board
  @board[@ball_y][@ball_x] = '#'
end

while true
  @ball_x += @dx
  if @ball_x >= @width
    @ball_x = @width -1
    @dx *= -1
  elsif @ball_x < 0
    @ball_x = 0
    @dx *= -1
  end

  @ball_y += @dy
  if @ball_y >= @height
    @ball_y = @height -1
    @dy *= -1
  elsif @ball_y < 0
    @ball_y = 0
    @dy *= -1
  end

  update_board
  print_board

  sleep 1
end



