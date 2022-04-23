#===============================================================================
# Filename:    common.rb
#
# Developer:   Raku (rakudayo@gmail.com)
#              XXXX
#
# Description: This file contains all global variables and functions which are
#    common to all of the import/export scripts.
#===============================================================================

# Add bin directory to the Ruby search path
#$LOAD_PATH << "C:/bin"

require 'yaml'
require 'tmpdir'
require 'parallel'

CHECKSUMS_FILE = 'checksums.csv'

# This is the filename where the startup timestamp is dumped.  Later it can
# be compared with the modification timestamp for data files to determine
# if they need to be exported.
TIME_LOG_FILE = "timestamp.bin"

#----------------------------------------------------------------------------
# recursive_mkdir: Creates a directory and all its parent directories if they
# do not exist.
#   directory: The directory to create
#----------------------------------------------------------------------------
def recursive_mkdir( directory )
  begin
    # Attempt to make the directory
    Dir.mkdir( directory )
  rescue Errno::ENOENT
    # Failed, so let's use recursion on the parent directory
    base_dir = File.dirname( directory )
    recursive_mkdir( base_dir )
    
    # Make the original directory
    Dir.mkdir( directory )
  end
end

#----------------------------------------------------------------------------
# print_separator: Prints a separator line to stdout.
#----------------------------------------------------------------------------
def print_separator( enable = $CONFIG.verbose )
  puts "-" * 80 if enable
end

#----------------------------------------------------------------------------
# puts_verbose: Prints a string to stdout if verbosity is enabled.
#   s: The string to print
#----------------------------------------------------------------------------
def puts_verbose(s = "")
  puts s if $CONFIG.verbose
end

#----------------------------------------------------------------------------
# file_modified_since?: Returns true if the file has been modified since the
# specified timestamp.
#   filename: The name of the file.
#   timestamp: The timestamp to check if the file is newer than.
#----------------------------------------------------------------------------
def file_modified_since?( filename, timestamp )
  modified_timestamp = File.mtime( filename )
  return (modified_timestamp > timestamp)
end

#----------------------------------------------------------------------------
# data_file_exported?: Returns true if the data file has been exported to yaml.
#   filename: The name of the data file.
#----------------------------------------------------------------------------
def data_file_exported?(filename)
  exported_filename = $PROJECT_DIR + '/' + $CONFIG.yaml_dir + '/' + File.basename(filename, File.extname(filename)) + ".yaml"
  return File.exist?( exported_filename )
end

#----------------------------------------------------------------------------
# dump_startup_time: Dumps the current system time to a temporary file.
#   directory: The directory to dump the system tile into.
#----------------------------------------------------------------------------
def dump_startup_time
  File.open( $PROJECT_DIR + '/' + TIME_LOG_FILE, "w+" ) do |outfile|
    Marshal.dump( Time.now, outfile )
  end
end

#----------------------------------------------------------------------------
# load_startup_time: Loads the dumped system time from the temporary file.
#   directory: The directory to load the system tile from.
#----------------------------------------------------------------------------
def load_startup_time(delete_file = false)
  t = nil
  if File.exist?( $PROJECT_DIR + '/' + TIME_LOG_FILE )
    File.open( $PROJECT_DIR + '/' + TIME_LOG_FILE, "r+" ) do |infile|
      t = Marshal.load( infile )
    end
    if delete_file then File.delete( $PROJECT_DIR + '/' + TIME_LOG_FILE ) end
  end
  t
end

def yaml_stable_ref(input_file, output_file)
  i = 1
  j = 1
  queue = Queue.new
  File.open(output_file, 'w') do |output|
    File.open(input_file, 'r').each do |line|
      if ! line[' &'].nil? || ! line[' *'].nil?
        match = line.match(/^ *(?:-|[a-zA-Z0-9_]++:) (?<type>[&*])(?<reference>[0-9]++)/)
        unless match.nil?
          if match[:type] === '&'
            queue.push(match[:reference])
            line[' &' + match[:reference]] = ' &' + i.to_s
            i += 1
          elsif match[:reference] === queue.pop()
            line[' *' + match[:reference]] = ' *' + j.to_s
            j += 1
            if queue.empty?
              i = 1
              j = 1
            end
          else
            raise "Unexpected alias " + match[:reference]
          end
        end
      end
      output.print line
    end
  end
end

class FileRecord
  attr_accessor :name
  attr_accessor :yaml_checksum
  attr_accessor :data_checksum

  def initialize(name, yaml_checksum, data_checksum)
    @name=name
    @yaml_checksum=yaml_checksum
    @data_checksum=data_checksum
  end
end

def load_checksums
  hash = {}
  if File.exist?($CONFIG.yaml_dir + '/' + CHECKSUMS_FILE)
    File.open($CONFIG.yaml_dir + '/' + CHECKSUMS_FILE, 'r').each do |line|
      name, yaml_checksum, data_checksum = line.rstrip.split(',', 3)
      hash[name] = FileRecord.new(name, yaml_checksum, data_checksum)
    end
  end
  return hash
end

def save_checksums(hash)
  File.open($CONFIG.yaml_dir + '/' + CHECKSUMS_FILE, 'w') do |output|
    hash.each_value do |record|
      output.print "#{record.name},#{record.yaml_checksum},#{record.data_checksum}\n"
    end
  end
end

def skip_file(record, data_checksum, yaml_checksum, import_only)
  return false if $FORCE || data_checksum.nil? || yaml_checksum.nil?
  return true if import_only
  return false if record.nil?
  return (data_checksum === record.data_checksum && yaml_checksum === record.yaml_checksum)
end

class Config
  attr_accessor :data_dir
  attr_accessor :yaml_dir
  attr_accessor :backup_dir
  attr_accessor :data_ignore_list
  attr_accessor :import_only_list
  attr_accessor :verbose
  attr_accessor :magic_number
  attr_accessor :startup_map
  attr_accessor :patch_changed
  attr_accessor :patch_always
  attr_accessor :base_commit

  def initialize(config)
    @data_dir         = config['data_dir']
    @yaml_dir         = config['yaml_dir']
    @backup_dir       = config['backup_dir']
    @data_ignore_list = config['data_ignore_list']
    @import_only_list = config['import_only_list']
    @verbose          = config['verbose']
    @magic_number     = config['magic_number']
    @startup_map      = config['startup_map']
    @patch_always     = config['patch_always']
    @patch_changed    = config['patch_changed']
    @base_commit      = config['base_commit']
  end
end

def import_file(file, checksums, input_dir, output_dir)
  start_time = Time.now
  filename = format_rxdata_name(File.basename(file, '.yaml'))
  name = File.basename(filename, '.rxdata')
  record = checksums[name]
  yaml_file = input_dir + file
  data_file = output_dir + filename
  import_only = $CONFIG.import_only_list.include?(filename)
  yaml_checksum = calculate_checksum(yaml_file)
  data_checksum = File.exist?(data_file) ? calculate_checksum(data_file) : nil
  local_file = input_dir + name + '.local.yaml'
  local_merge = File.exist?(local_file)
  now = Time.now.strftime("%Y-%m-%d_%H-%M-%S")

  # Skip import if checksum matches
  return nil if ! local_merge && skip_file(record, data_checksum, yaml_checksum, import_only)

  # Load the data from yaml file
  data = load_yaml(yaml_file)

  if data === false
    puts 'Error: ' + file + ' is not a valid YAML file.'
    exit 1
  end

  if local_merge
    local_data = load_yaml(local_file)
    if name == 'System'
      data.magic_number = local_data.magic_number
      data.edit_map_id = local_data.edit_map_id
    elsif name == 'MapInfos'
      data.each do |key, map|
        local_map = local_data[key]
        unless local_map.nil?
          map.expanded = local_map.expanded
          map.scroll_x = local_map.scroll_x
          map.scroll_y = local_map.scroll_y
        end
      end
    end
  end

  # Create backup of .rxdata file
  File.rename(data_file, $CONFIG.backup_dir + '/' + now + '.' + name + '.rxdata') if File.exist?(data_file)

  # Dump the data to .rxdata file
  save_rxdata(data_file, data)

  # Update checksums
  unless import_only
    checksums[name] = FileRecord.new(name, yaml_checksum, calculate_checksum(data_file))
  end

  # Calculate the time to dump the data file
  dump_time = Time.now - start_time
end

def export_file(file, checksums, maps, input_dir, output_dir)
  start_time = Time.now
  name = File.basename(file, '.rxdata')
  record = checksums[name]
  data_file = input_dir + file
  yaml_file = output_dir + format_yaml_name(name, maps)
  import_only = $CONFIG.import_only_list.include?(file)
  yaml_checksum = File.exist?(yaml_file) ? calculate_checksum(yaml_file) : nil
  data_checksum = calculate_checksum(data_file)

  # Skip import if checksum matches
  return nil if skip_file(record, data_checksum, yaml_checksum, import_only)

  # Load the data from rmxp's data file
  data = load_rxdata(data_file)

  # Handle default values for the System data file
  if name == 'System'
    save_yaml(output_dir + name + '.local.yaml', data)
    # Prevent the 'magic_number' field of System from always conflicting
    data.magic_number = $CONFIG.magic_number unless $CONFIG.magic_number == -1
    # Prevent the 'edit_map_id' field of System from conflicting
    data.edit_map_id = $CONFIG.startup_map unless $CONFIG.startup_map == -1
  elsif name == 'MapInfos'
    save_yaml(output_dir + name + '.local.yaml', data)
    data.each do |key, map|
      map.expanded = false
      map.scroll_x = 0
      map.scroll_y = 0
    end
    # Sort the maps hash by keys to keep stable order in yaml.
    data = data.sort.to_h
  elsif data.instance_of?(RPG::Map)
    # Sort the events hash by keys to keep stable order in yaml.
    data.events = data.events.sort.to_h
  end

  # Dump the data to a YAML file
  export_file = Dir.tmpdir() + '/' + file + '_export.yaml'
  save_yaml(export_file, data)

  # Simplify references in yaml to avoid conflicts
  fixed_file = Dir.tmpdir() + '/' + file + '_fixed.yaml'
  yaml_stable_ref(export_file, fixed_file)

  # Delete other maps with same number to handle map rename
  Dir.glob(output_dir + name + ' - *.yaml').each { |file| File.delete(file) }
  Dir.glob(output_dir + name + '.yaml').each { |file| File.delete(file) }

  # Save map yaml
  File.rename(fixed_file, yaml_file)

  # Update checksums
  unless import_only
    checksums[name] = FileRecord.new(name, calculate_checksum(yaml_file), data_checksum)
  end

  # Calculate the time to dump the .yaml file
  dump_time = Time.now - start_time
end

def detect_cores
  begin
    return Parallel.physical_processor_count
  rescue
    # Fallback because so far I was unable to compile win32ole into the exe file
    return `WMIC CPU Get NumberOfCores /Format:List`.match(/NumberOfCores=([0-9]++)/)[1].to_i
  end
end

def load_yaml(yaml_file)
  data = nil
  File.open( yaml_file, "r+" ) do |input_file|
    data = YAML::unsafe_load( input_file )
  end
  return data['root']
end

def save_yaml(yaml_file, data)
  File.open(yaml_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |output_file|
    File.write(output_file, YAML::dump({'root' => data}))
  end
end

def load_rxdata(data_file)
  # Change strings to utf-8 to prevent base64 encoding in yaml
  load = -> (value) {
    if value.instance_of? RPG::EventCommand
      value.parameters.each do |parameter|
        parameter.force_encoding('utf-8') if parameter.instance_of? String
      end
    end
    value
  }

  data = nil
  File.open( data_file, "r+" ) do |input_file|
    data = Marshal.load( input_file, load )
  end

  return data
end

def save_rxdata(data_file, data)
  File.open( data_file, "w+" ) do |output_file|
    Marshal.dump( data, output_file )
  end
end

def load_maps
  unless File.exist?($CONFIG.data_dir + '/MapInfos.rxdata')
    raise "Missing MapInfos.rxdata"
  end
  return load_rxdata($CONFIG.data_dir + '/MapInfos.rxdata')
end

def format_yaml_name(name, maps)
  match = name.match(/^Map0*+(?<number>[0-9]++)$/)
  return name + '.yaml' if match.nil?
  map_name = maps.fetch(match[:number].to_i).name.gsub(/[^0-9A-Za-z ]/, '')
  return name + '.yaml' if map_name == ''
  return name + ' - ' + map_name + '.yaml'
end

def format_rxdata_name(name)
  match = name.match(/^(?<map>Map[0-9]++)(?: - .*)?/)
  return name + '.rxdata' if match.nil?
  return match[:map] + '.rxdata'
end

def ensure_non_duplicate_maps(files)
  data_files = files.map { |file| format_rxdata_name(File.basename(file, '.yaml')) }
  duplicates = data_files.tally.select { |_, count| count > 1 }.keys
  raise "Found multiple yamls for same map: #{duplicates}" unless duplicates.empty?
end

def calculate_checksum(file)
  return File.mtime(file).to_i.to_s + '/' + File.size(file).to_s
end

def generate_patch()
  if $CONFIG.base_commit.nil? || ! $CONFIG.base_commit.match(/^[a-z0-9]+$/)
    puts 'Specify the base_commit in eevee.yaml.'
    exit
  end

  command = 'git diff --exit-code --ignore-submodules --name-only --diff-filter=ACMRTUX ' + $CONFIG.base_commit + '..HEAD'
  files = nil
  Open3.popen3(command) do |stdin, stdout|
    files = stdout.read.split("\n")
  end

  files.select! { |file| File.fnmatch($CONFIG.patch_changed, file, File::FNM_EXTGLOB) }

  puts "Found #{files.length} changed files."

  File.delete('patch.zip') if File.exist?('patch.zip')

  Zip::File.open('patch.zip', create: true) do |zipfile|
    files.each do |file|
      if file.start_with?($CONFIG.yaml_dir + '/')
        file = $CONFIG.data_dir + '/' + format_rxdata_name(File.basename(file, '.yaml'))
      end
      zipfile.add(file, file)
    end
    Dir.glob($CONFIG.patch_always, File::FNM_EXTGLOB).each do |file|
      zipfile.add(file, file)
    end
  end
end

def clear_backups()
  files = Dir.entries( $CONFIG.backup_dir )
  files = files.select { |e| File.extname(e) == ".rxdata" }
  files = files.select { |e| ! file_modified_since?($CONFIG.backup_dir + '/' + e, Time.now - 7*24*60*60) }
  files.each do |file|
    File.delete($CONFIG.backup_dir + '/' + file)
  end
end
