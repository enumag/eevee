$COMMAND = ARGV[0] || ''
$PROJECT_DIR = Dir.pwd + '/'
$FORCE = $COMMAND != "rmxp"

require_relative 'rmxp/rgss'
require_relative 'src/common'
require_relative 'src/data_importer_exporter'

# Setup config filename
config_filename = "eevee.yaml"
# Setup the config file path
$CONFIG_PATH = $PROJECT_DIR + "/" + config_filename

# Read the config YAML file
config = nil
File.open( $CONFIG_PATH, "r+" ) do |configfile|
  config = YAML::load( configfile )
end

# Initialize configuration parameters
$CONFIG = Config.new(config)

plugin = DataImporterExporter.new

if $COMMAND == "import"
  plugin.on_start
elsif $COMMAND == "export"
  plugin.on_exit
elsif $COMMAND == "rmxp"
  require 'listen'
  require 'wdm'

  plugin.on_start

  # Dump the system time at startup into a file to read later
  dump_startup_time

  # Definitely do not want the user to close the command window
  puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  puts "!!!DO NOT CLOSE THIS COMMAND WINDOW!!!"
  puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  puts_verbose

  listener = Listen.to($PROJECT_DIR + $CONFIG.data_dir) do |modified, added, removed|
    plugin.on_exit
  end
  listener.start

  # Start RMXP
  File.write($PROJECT_DIR + '/Game.rxproj', 'RPGXP 1.05')
  system('START /WAIT /D "' + $PROJECT_DIR + '" Game.rxproj')
  File.delete($PROJECT_DIR + '/Game.rxproj')

  plugin.on_exit

  clear_backups

  # Delete the startup timestamp
  load_startup_time(true)
elsif $COMMAND == "patch"
  require 'open3'
  require 'zip'

  generate_patch
else
  puts "Unknown command " + $COMMAND
end
