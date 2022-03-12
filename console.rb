$COMMAND = ARGV[0] || "start"
$PROJECT_DIR = Dir.pwd + '/'

$DATA_TYPE = "rxdata"
$RE_EXPORT = false

require_relative 'rmxp/rgss'
require_relative 'common'
require_relative 'plugin_base'
require_relative 'plugins/data_importer_exporter'

plugin = DataImporterExporter.new

if $COMMAND == "import"
    plugin.on_start
elsif $COMMAND == "export"
    $RE_EXPORT = true
    plugin.on_exit
elsif $COMMAND == "start"
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
else
    puts "Unknown command " + $COMMAND
end
