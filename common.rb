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

# Setup config filename
config_filename = "config.yaml"
# Setup the config file path
$CONFIG_PATH = $PROJECT_DIR + "/" + config_filename

# Read the config YAML file
config = nil
File.open( $CONFIG_PATH, "r+" ) do |configfile|
  config = YAML::load( configfile )
end

# Initialize configuration parameters
$DATA_DIR            = config['data_dir']
$YAML_DIR            = config['yaml_dir']
$DATA_IGNORE_LIST    = config['data_ignore_list']
$IMPORT_ONLY_LIST    = config['import_only_list']
$VERBOSE             = config['verbose']
$MAGIC_NUMBER        = config['magic_number']
$DEFAULT_STARTUP_MAP = config['edit_map_id']
puts

$CHECKSUMS_FILE = $DATA_DIR + '/checksums.csv'

# This is the filename where the startup timestamp is dumped.  Later it can
# be compared with the modification timestamp for data files to determine
# if they need to be exported.
$TIME_LOG_FILE = "timestamp.bin"

# An array of invalid Windows filename strings and their substitutions. This
# array is used to modify the script title in RMXP's script editor to construct
# a filename for saving the script out to the filesystem.
$INVALID_CHARS_FOR_FILENAME = [
    [" - ", "_"],
    [" ", "_"],
    ["-", "_"],
    [":", "_"],
    ["/", "_"],
    ["\\", "_"],
    ["*", "_"],
    ["|", "_"],
    ["<", "_"],
    [">", "_"],
    ["?", "_"]
]

# Lengths of the columns in the script export digest
$COLUMN1_WIDTH  = 12
$COLUMN2_WIDTH  = 45

# Length of a filename (for output formatting purposes)
$FILENAME_WIDTH = 35

# Length of a line separator for output
$LINE_LENGTH = 80

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
def print_separator( enable = $VERBOSE )
  puts "-" * $LINE_LENGTH if enable
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
  puts s if $VERBOSE
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
  exported_filename = $PROJECT_DIR + '/' + $YAML_DIR + '/' + File.basename(filename, File.extname(filename)) + ".yaml"
  return File.exist?( exported_filename )
end

#----------------------------------------------------------------------------
# dump_startup_time: Dumps the current system time to a temporary file.
#   directory: The directory to dump the system tile into.
#----------------------------------------------------------------------------
def dump_startup_time
  File.open( $PROJECT_DIR + '/' + $TIME_LOG_FILE, "w+" ) do |outfile|
    Marshal.dump( Time.now, outfile )
  end
end

#----------------------------------------------------------------------------
# load_startup_time: Loads the dumped system time from the temporary file.
#   directory: The directory to load the system tile from.
#----------------------------------------------------------------------------
def load_startup_time(delete_file = false)
  t = nil
  if File.exist?( $PROJECT_DIR + '/' + $TIME_LOG_FILE )
    File.open( $PROJECT_DIR + '/' + $TIME_LOG_FILE, "r+" ) do |infile|
      t = Marshal.load( infile )
    end
    if delete_file then File.delete( $PROJECT_DIR + '/' + $TIME_LOG_FILE ) end
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
  if File.exist?($CHECKSUMS_FILE)
    File.open($CHECKSUMS_FILE, 'r').each do |line|
      name, yaml_checksum, data_checksum = line.rstrip.split(',', 3)
      hash[name] = FileRecord.new(name, yaml_checksum, data_checksum)
    end
  end
  return hash
end

def save_checksums(hash)
  File.open($CHECKSUMS_FILE, 'w') do |output|
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
