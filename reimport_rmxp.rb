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

$DATA_TYPE = "rxdata"
$RE_EXPORT = false

require_relative 'rmxp/rgss'
require_relative 'common'
require_relative 'plugin_base'
require_relative 'plugins/data_importer_exporter'

#######################################
#             SCRIPT
#######################################

plugin = DataImporterExporter.new
plugin.on_start
