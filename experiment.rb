require_relative 'rmxp/rgss'
require_relative 'rmxp/rpg_dumper'
require_relative 'rmxp/rpg_factory'
require_relative 'src/common'

INDENT_SIZE = 2

def indent(level)
  return ' ' * level * INDENT_SIZE
end

def save_rb(file, data)
  save_yaml('var/map_original_tmp.yaml', data)
  yaml_stable_ref('var/map_original_tmp.yaml', 'var/map_original.yaml')
  marshal = Marshal.dump(data)

  measure do
    print 'dump ruby '
    ruby = (RPGDumper.new).dump_ruby(data)
    File.write('var/map.rb', ruby)
  end

  reconstructed = nil
  measure do
    print 'load ruby '
    ruby = File.read('var/map.rb')
    reconstructed = (RPGFactory.new).evaluate(ruby)
  end

  # print_rb(ruby)

  measure do
    print 'dump yaml '
    save_yaml('var/map_tmp.yaml', reconstructed)
    yaml_stable_ref('var/map_tmp.yaml', 'var/map.yaml')
  end

  yaml = nil
  measure do
    print 'load yaml '
    yaml = load_yaml('var/map.yaml')
  end

  # measure do
  #   print 'dump rxdata '
  #   File.open('var/map.rxdata', "wb") { |f|
  #     Marshal.dump(reconstructed, f)
  #   }
  # end

  # load = nil
  # measure do
  #   print 'load rxdata '
  #   File.open( 'var/map.rxdata', "r+" ) do |f|
  #     load = Marshal.load(f)
  #   end
  # end

  puts marshal == Marshal.dump(reconstructed)
  puts Marshal.dump(yaml) == Marshal.dump(reconstructed)
  # puts Marshal.dump(yaml) == Marshal.dump(load)
  match = File.read('var/map_original.yaml') == File.read('var/map.yaml')
  puts match
  exit unless match
end

def measure(&block)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  block.call
  finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  elapsed = finish - start
  puts elapsed
end

def print_rb(code)
  code.lines.each_with_index do |line, key|
    puts key.to_s.rjust(6, ' ') + '  '+ line
  end
end

# data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map369 - Critical Capture.yaml')
# data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map006 - Department Store 11F.yaml')
data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map011 - Blacksteam Factory B1F.yaml')
data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map150 - Rhodochrine Jungle.yaml')

range = 0..999

range.each do |id|
  file = 'C:\Projects\Reborn\Reborn\Data/Map' + id.to_s.rjust(3, '0') + '.rxdata'
  if File.exist?(file)
    puts file
    data = load_rxdata(file)
    save_rb('', data)

    FileUtils.cp('var/map.rb', 'C:\Projects\Reborn\Reborn\DataRuby/Map' + id.to_s.rjust(3, '0') + '.rb')
  else
    puts 'skip ' + id.to_s
  end
end

# TODO:
# CommonEvents, MapInfos and other rxdata
# Consider adding variable and switch name comments
# Consider map() function and a name comment for transfer player?
# Consider character() function and a name comment but not in CommonEvents
# Consider comments with common event name
# Use Change encounter command in agate city raid, but careful with fly
# Consider function and name comment for animations
