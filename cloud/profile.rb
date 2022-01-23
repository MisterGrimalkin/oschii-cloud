require_relative 'oschii'

include Oschii

name = ARGV[0]

if name.empty?
  puts 'Specify Oschii name'
  exit
end

@oschii = cloud(silent: true).wait_for(name)

unless @oschii
  exit
end

filename = "#{name}_profile_#{Time.now.to_i}.csv"
file = File.open(filename, 'a')

puts "\nWriting to #{filename}....\n"

header = 'Time,Cycle Time,Free Heap,Free Storage'
puts header
file.puts header

while true
  status = @oschii.status
  free_heap = ((status['freeHeap'].to_f / status['totalHeap'].to_f) * 100).to_i
  free_storage = ((status['freeSPIFFS'].to_f / status['totalSPIFFS'].to_f) * 100).to_i
  line = "#{status['millis']},#{status['cycleTime']},#{free_heap},#{free_storage}"
  puts line
  file.puts line
end
