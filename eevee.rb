$COMMAND = ARGV[0] || ''
$PROJECT_DIR = Dir.pwd + '/'
$SEED = $PROJECT_DIR.hash.to_s
$VERSION = 'dev'

require_relative 'rmxp/rgss'
require_relative 'src/common'
require_relative 'src/data_importer_exporter'

# Setup config filename
config_filename = "eevee.yaml"
# Setup the config file path
$CONFIG_PATH = $PROJECT_DIR + config_filename

if File.exist?($CONFIG_PATH)
  # Read the config YAML file
  config = nil
  File.open( $CONFIG_PATH, "r+" ) do |configfile|
    config = YAML::load( configfile )
  end

  # Initialize configuration parameters
  $CONFIG = Config.new(config)
else
  puts "Missing eevee.yaml configuration file."
  puts
  $COMMAND = ""
end

plugin = DataImporterExporter.new

if $COMMAND == "import"
  plugin.on_start

  clear_backups
elsif $COMMAND == "export"
  plugin.on_exit(load_maps)
elsif $COMMAND == "rmxp"
  require 'listen'
  require 'wdm'

  plugin.on_start

  # Save the system time at startup
  $STARTUP_TIME = Time.now

  # Definitely do not want the user to close the command window
  puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  puts "!!!DO NOT CLOSE THIS COMMAND WINDOW!!!"
  puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  puts_verbose

  # Load map names before hand to be able to properly delete maps.
  maps = load_maps
  listener = Listen.to($PROJECT_DIR + $CONFIG.data_dir) do |modified, added, removed|
    plugin.on_exit(maps, removed)
    maps = load_maps
  end
  listener.start

  pid = nil
  if $CONFIG.resizer
    if File.exist?($PROJECT_DIR + 'ResizeEnableRunner.exe')
      # Start Resizer tool if it exists
      pid = Process.spawn('"' + $PROJECT_DIR + 'ResizeEnableRunner.exe"')
      puts "ResizeEnableRunner.exe started (" + pid.to_s + ")."
    else
      puts "ResizeEnableRunner.exe not found."
    end
  end

  # Start RMXP
  File.write($PROJECT_DIR + 'Game.rxproj', 'RPGXP 1.05')
  system('START /WAIT /D "' + $PROJECT_DIR + '" Game.rxproj')
  begin
    File.delete($PROJECT_DIR + 'Game.rxproj')
  rescue Errno::ENOENT
  end

  # Cleanup
  system("taskkill /im #{pid} /f /t >nul 2>&1") if pid

  plugin.on_exit(maps)

  clear_backups
elsif $COMMAND == "patch"
  base_tag = ARGV[1] || nil
  password = ARGV[2] || nil

  generate_patch(base_tag, password)
elsif $COMMAND == "shuffle"
  source = ARGV[1] || nil
  target = ARGV[2] || nil

  shuffle(source, target)
elsif $COMMAND == "assets"
  assets
elsif $COMMAND == "tiles"
  tiles
else
  puts "eevee version: " + $VERSION
  puts
  puts "Available commands:"

  help "export",  "Export rxdata files to yaml/ruby"
  help "import",  "Import yaml/ruby files back to rxdata filed"
  help "rmxp",    "Open RPG Maker and watch for changes"
  help "patch",   "Generate a patch file"
  help "shuffle", "Move a switch or variable to new ID"
  help "assets",  "Check ruby files for usage of missing assets"
  help "tiles",   "Check ruby files for invalid tiles"

  if STDIN.isatty
    puts
    puts "Press enter to exit..."
    gets
  end

  exit 1
end
