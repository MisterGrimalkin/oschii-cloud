require_relative 'oschii'

include Oschii

@oschii = cloud(silent: true).wait_for('ada')

exit unless @oschii

@board = []

@width = 5
@height = 9

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
      print "#{@board[y][x]} "
      if @board[y][x] == '#'
        message += [11, 11, 11]
      else
        message += [0, 0, 0]
      end
    end
    puts
  end
  puts
  ada.send_osc :display, *message
end

@ball_x = 2
@ball_y = 4

@dx = 1
@dy = 1

def update_board
  clear_board
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

  sleep 0.2
end



