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

require_relative 'addons'

require 'yaml'
require 'digest'

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
$VERBOSE             = config['verbose']
$MAGIC_NUMBER        = config['magic_number']
$DEFAULT_STARTUP_MAP = config['edit_map_id']
puts

# This is the filename where the startup timestamp is dumped.  Later it can
# be compared with the modification timestamp for data files to determine
# if they need to be exported.
$TIME_LOG_FILE = "timestamp.bin"

# An array of invalid Windows filename strings and their substitutions. This
# array is used to modify the script title in RMXP's script editor to construct
# a filename for saving the script out to the filesystem.
$INVALID_CHARS_FOR_FILENAME= [ 
    [" - ", "_"],
    [" ",   "_"],
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

#----------------------------------------------------------------------------
# generate_filename: Generates a filename given an RGSS script entry.
#   script: An entry for a script in the loaded Scripts file. This
#           is a three element array with the 0th element as the unique id,
#           the 1st element is the script's title in RM, and the 3rd 
#           element is the script's compressed text
#----------------------------------------------------------------------------
def generate_filename(script)
  (Zlib::Inflate.inflate(script[2]) != '' ? "#{fix_name(script[1])}.rb" : 'EMPTY')
end

#----------------------------------------------------------------------------
# generate_filename: Generates a filename given an RGSS script's title.
#   title: The title of the script in RM's script editor
#----------------------------------------------------------------------------
def fix_name(title)
  result = String.new( title )
  # Replace all invalid characters
  for substitution in $INVALID_CHARS_FOR_FILENAME
    result.gsub!(substitution[0], substitution[1])
  end
  result
end