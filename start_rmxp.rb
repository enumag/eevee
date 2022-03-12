#===============================================================================
# Filename:    start_rmxp.rb
#
# Developer:   Raku (rakudayo@gmail.com)
#
# Description: This script creates all plugins in the Plugins directory and
# executes their on_start event methods and starts RMXP.  When RMXP is closed,
# the on_exit event method of each plugin is called.
#===============================================================================

# Setup the project directory from the command-line argument
OS_VERSION = `ver`.strip
$PROJECT_DIR = ARGV[0]
# if OS_VERSION.index( "Windows XP" )
#   $PROJECT_DIR = String.new( $PROJECT_DIR )
# elsif OS_VERSION.index( "Windows" )
#   $PROJECT_DIR = String.new( $PROJECT_DIR ).gsub! "/", "\\"
# end

$DATA_TYPE = "rxdata"
$RE_EXPORT = false

require_relative 'rmxp/rgss'
require_relative 'common'
require_relative 'plugin_base'
require_relative 'plugins/data_importer_exporter'

require 'listen'
require 'wdm'

#######################################
#             SCRIPT
#######################################

# Make sure RMXP isn't already running
exit if check_for_rmxp(true)

plugin = DataImporterExporter.new
plugin.on_start

# Dump the sytem time at startup into a file to read later
dump_startup_time

# Definitely do not want the user to close the command window
puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
puts "!!!DO NOT CLOSE THIS COMMAND WINDOW!!!"
puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
puts_verbose

# P.S. too bored to refactor :(
listener = Listen.to($PROJECT_DIR + $DATA_DIR) do |modified, added, removed|
    plugin.on_exit
end
listener.start

# Start RMXP
command = 'START /B /WAIT /D"' + $PROJECT_DIR + '" Game.rxproj'
system(command)

plugin.on_exit

# Delete the startup timestamp
load_startup_time(true)