module Oschii
  class OscMonitor
    COL_WIDTH = 40

    def initialize(cloud)
      @cloud = cloud
      @values = {}
    end

    attr_reader :cloud, :values

    def add(name, max: 100)
      unless values[name.to_sym]
        values[name.to_sym] = {value: nil, max: max}
        cloud.capture_osc name do |value|
          values[name.to_sym][:value] = value
        end
      end

      values[name.to_sym][:max] = max
    end

    def run
      puts
      values.each do |k, v|
        print " #{k}".ljust (COL_WIDTH+4)
      end
      puts
      while true
        render
        sleep 0.01
      end
    end

    def render
      print "\r"
      values.each do |k, v|
        print sensor_bar(v)
      end
    end

    def sensor_bar(value)
      result = '['
      norm = [value[:value].to_f / value[:max], 1.0].min * COL_WIDTH
      COL_WIDTH.times do |i|
        if i < norm
          result += '■'
        else
          result += ':'
        end
      end
      result += ']  '
    end


  end
end