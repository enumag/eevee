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
require 'digest'
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
# pause_prompt: Prints a pause prompt to stdout.
#----------------------------------------------------------------------------
def pause_prompt
  puts "Press ENTER to continue . . ."
  STDIN.getc
end

#----------------------------------------------------------------------------
# pause_prompt: Prints a string to stdout if verbosity is enabled.
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
      if not line[' &'].nil? or not line[' *'].nil?
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
  return false if $FORCE or data_checksum.nil? or yaml_checksum.nil?
  return true if import_only
  return false if record.nil?
  return (data_checksum === record.data_checksum and yaml_checksum === record.yaml_checksum)
end

class Config
  attr_accessor :data_dir
  attr_accessor :yaml_dir
  attr_accessor :data_ignore_list
  attr_accessor :import_only_list
  attr_accessor :verbose
  attr_accessor :magic_number
  attr_accessor :startup_map

  def initialize(config)
    @data_dir         = config['data_dir']
    @yaml_dir         = config['yaml_dir']
    @data_ignore_list = config['data_ignore_list']
    @import_only_list = config['import_only_list']
    @verbose          = config['verbose']
    @magic_number     = config['magic_number']
    @startup_map      = config['edit_map_id']
  end
end

def import_file(file, checksums, input_dir, output_dir)
  data = nil
  start_time = Time.now
  name = File.basename(file, ".yaml")
  record = checksums[name]
  filename = name + ".rxdata"
  yaml_file = input_dir + file
  data_file = output_dir + filename
  import_only = $CONFIG.import_only_list.include?(filename)
  yaml_checksum = Digest::SHA256.file(yaml_file).hexdigest
  data_checksum = File.exist?(data_file) ? Digest::SHA256.file(data_file).hexdigest : nil

  # Skip import if checksum matches
  return nil if skip_file(record, data_checksum, yaml_checksum, import_only)

  # Load the data from yaml file
  File.open( yaml_file, "r+" ) do |input_file|
    data = YAML::unsafe_load( input_file )
  end

  if data === false
    puts 'Error: ' + file + ' is not a valid YAML file.'
    exit 1
  end

  # Dump the data to .rxdata or .rvdata file
  File.open( data_file, "w+" ) do |output_file|
    Marshal.dump( data['root'], output_file )
  end

  # Update checksums
  unless import_only
    checksums[name] = FileRecord.new(name, yaml_checksum, Digest::SHA256.file(data_file).hexdigest)
  end

  # Calculate the time to dump the data file
  dump_time = Time.now - start_time
end

def export_file(file, checksums, input_dir, output_dir)
  data = nil
  start_time = Time.now
  name = File.basename(file, ".rxdata")
  record = checksums[name]
  data_file = input_dir + file
  yaml_file = output_dir + name + ".yaml"
  import_only = $CONFIG.import_only_list.include?(file)
  yaml_checksum = File.exist?(yaml_file) ? Digest::SHA256.file(yaml_file).hexdigest : nil
  data_checksum = Digest::SHA256.file(data_file).hexdigest

  # Skip import if checksum matches
  return nil if skip_file(record, data_checksum, yaml_checksum, import_only)

  # Load the data from rmxp's data file
  File.open( data_file, "r+" ) do |input_file|
    data = Marshal.load( input_file )
  end

  # Handle default values for the System data file
  if file == "System.rxdata"
    # Prevent the 'magic_number' field of System from always conflicting
    data.magic_number = $CONFIG.magic_number unless $CONFIG.magic_number == -1
    # Prevent the 'edit_map_id' field of System from conflicting
    data.edit_map_id = $CONFIG.startup_map unless $CONFIG.startup_map == -1
  end

  # Dump the data to a YAML file
  export_file = Dir.tmpdir() + '/' + file + '_export.yaml'
  File.open(export_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |output_file|
    File.write(output_file, YAML::dump({'root' => data}))
  end

  # Dirty workaround to sort the keys in yaml
  sorted_file = Dir.tmpdir() + '/' + file + '_sorted.yaml'
  command = 'START /B /WAIT /D"' + $PROJECT_DIR + '" yq.exe "sort_keys(..)" "' + export_file + '" > "' + sorted_file + '"'
  system(command)

  # Simplify references in yaml to avoid conflicts
  fixed_file = Dir.tmpdir() + '/' + file + '_fixed.yaml'
  yaml_stable_ref(sorted_file, fixed_file)
  File.rename(fixed_file, yaml_file)

  # Rewrite data file if the checksum is wrong and RMXP is not open
  unless import_only
    File.open( yaml_file, "r+" ) do |input_file|
      data = YAML::unsafe_load( input_file )
    end
    final_checksum = Digest::SHA256.hexdigest Marshal.dump( data['root'] )
    if data_checksum != final_checksum and $FORCE
      File.open( data_file, "w+" ) do |output_file|
        Marshal.dump( data['root'], output_file )
      end
    end
    checksums[name] = FileRecord.new(
      name,
      Digest::SHA256.file(yaml_file).hexdigest,
      final_checksum
    )
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
