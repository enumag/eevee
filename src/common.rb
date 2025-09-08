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

require 'etc'
require 'yaml'
require 'tmpdir'
require 'parallel'
require 'fileutils'

CHECKSUMS_FILE = 'checksums.csv'

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
  puts "-" * 100 if enable
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
# data_file_exported?: Returns true if the data file has been exported.
#   filename: The name of the data file.
#----------------------------------------------------------------------------
def data_file_exported?(filename)
  exported_filename = $PROJECT_DIR + $CONFIG.export_dir + '/' + File.basename(filename, File.extname(filename)) + $CONFIG.export_extension
  return File.exist?( exported_filename )
end

def yaml_stable_ref(input_file, output_file)
  i = 1
  j = 1
  k = 1
  queue = Queue.new
  hash = {}
  File.open(output_file, 'w') do |output|
    File.open(input_file, 'r').each do |line|
      if ! line[' &'].nil? || ! line[' *'].nil?
        match = line.match(/^ *(?:-|[a-zA-Z0-9_]++:) (?<type>[&*])(?<reference>[0-9]++)(?: !ruby\/object:(?<class>[a-zA-Z0-9:_]++))?/)
        unless match.nil?
          if match[:type] == '&' && match[:class] != 'RPG::MoveCommand'
            hash[match[:reference]] = k
            line[' &' + match[:reference]] = ' &x' + k.to_s
            k += 1
          elsif match[:type] == '*' && hash.key?(match[:reference])
            line[' *' + match[:reference]] = ' *x' + hash[match[:reference]].to_s
          elsif match[:type] == '&'
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
  attr_accessor :export_checksum
  attr_accessor :data_checksum

  def initialize(name, export_checksum, data_checksum)
    @name = name
    @export_checksum = export_checksum
    @data_checksum = data_checksum
  end
end

def load_checksums
  hash = {}
  if File.exist?($CONFIG.export_dir + '/' + CHECKSUMS_FILE)
    File.open($CONFIG.export_dir + '/' + CHECKSUMS_FILE, 'r').each do |line|
      next unless line.include?(",")
      name, export_checksum, data_checksum = line.chomp.split(',', 3)
      hash[name] = FileRecord.new(name, export_checksum, data_checksum)
    end
  end
  return hash
end

def save_checksums(commit, hash)
  File.open($CONFIG.export_dir + '/' + CHECKSUMS_FILE, 'w') do |output|
    output.print commit.to_s + "\n"
    hash.each_value do |record|
      output.print "#{record.name},#{record.export_checksum},#{record.data_checksum}\n"
    end
  end
end

def skip_file(record, data_checksum, export_checksum, import_only)
  return false if data_checksum.nil? || export_checksum.nil?
  return true if import_only
  return false if record.nil?
  return data_checksum == record.data_checksum && export_checksum == record.export_checksum
end

class Config
  attr_accessor :data_dir
  attr_accessor :yaml_dir
  attr_accessor :ruby_dir
  attr_accessor :backup_dir
  attr_accessor :file_list
  attr_accessor :import_only_list
  attr_accessor :half_pixels_list
  attr_accessor :verbose
  attr_accessor :magic_number
  attr_accessor :startup_map
  attr_accessor :resizer
  attr_accessor :patch_always
  attr_accessor :patch_never
  attr_accessor :patch_changed
  attr_accessor :base_tag
  attr_accessor :base_commit

  def initialize(config)
    @data_dir         = config['data_dir']
    @yaml_dir         = config['yaml_dir']
    @ruby_dir         = config['ruby_dir']
    @backup_dir       = config['backup_dir']
    @file_list        = config['file_list']
    @import_only_list = config['import_only_list']
    @half_pixels_list = config['half_pixels_list']
    @verbose          = config['verbose']
    @magic_number     = config['magic_number']
    @startup_map      = config['startup_map']
    @resizer          = config['resizer']
    @patch_always     = config['patch_always']
    @patch_never      = config['patch_never']
    @patch_changed    = config['patch_changed']
    @base_tag         = config['base_tag']
    @base_commit      = config['base_commit']
  end

  def export_dir
    return @ruby_dir unless @ruby_dir.nil?
    return @yaml_dir
  end

  def export_extension
    return @ruby_dir.nil? ? '.yaml' : '.rb'
  end

  def use_ruby?
    return ! @ruby_dir.nil?
  end
end

def import_file(file, checksums, input_dir, output_dir)
  start_time = Time.now
  filename = format_rxdata_name(File.basename(file, $CONFIG.export_extension))
  name = File.basename(filename, '.rxdata')
  record = checksums[name]
  export_file = input_dir + file
  data_file = output_dir + filename
  import_only = $CONFIG.import_only_list.include?(filename)
  export_checksum = calculate_checksum(export_file)
  data_checksum = File.exist?(data_file) ? calculate_checksum(data_file) : nil
  local_file = input_dir + name + '.local' + $CONFIG.export_extension
  local_merge = File.exist?(local_file)
  now = Time.now.strftime("%Y-%m-%d_%H-%M-%S")

  # Skip import if checksum matches
  return nil if ! local_merge && skip_file(record, data_checksum, export_checksum, import_only)

  # Load the data from yaml or ruby file
  data = $CONFIG.use_ruby? ? load_ruby(export_file) : load_yaml(export_file)

  if data === false
    puts 'Error: ' + file + ' is not a valid file.'
    exit 1
  end

  if local_merge
    local_data = $CONFIG.use_ruby? ? load_ruby(local_file) : load_yaml(local_file)
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
          map.order = local_map.order
        end
      end
    end
  end

  # Create backup of .rxdata file
  FileUtils.move(data_file, $CONFIG.backup_dir + '/' + now + '.' + name + '.rxdata') if File.exist?(data_file)

  # Dump the data to .rxdata file
  save_rxdata(data_file, data)

  # Update checksums
  unless import_only
    checksums[name] = FileRecord.new(name, export_checksum, calculate_checksum(data_file))
  end

  # Calculate the time to dump the data file
  dump_time = Time.now - start_time
end

def export_file(file, checksums, maps, input_dir, output_dir)
  start_time = Time.now
  name = File.basename(file, '.rxdata')
  record = checksums[name]
  data_file = input_dir + file
  export_file = output_dir + format_export_name(name, maps)
  import_only = $CONFIG.import_only_list.include?(file)
  export_checksum = File.exist?(export_file) ? calculate_checksum(export_file) : nil
  data_checksum = calculate_checksum(data_file)
  now = Time.now.strftime("%Y-%m-%d_%H-%M-%S")

  # Skip import if checksum matches
  return nil if skip_file(record, data_checksum, export_checksum, import_only)

  # Load the data from rmxp's data file
  data = load_rxdata(data_file)

  # Handle default values for the System data file
  if name == 'System'
    variables = data.variables
    switches = data.switches
    data.variables = []
    data.switches = []
    if $CONFIG.use_ruby?
      save_ruby(output_dir + name + '.local' + $CONFIG.export_extension, data)
    else
      save_yaml(output_dir + name + '.local' + $CONFIG.export_extension, data)
    end
    data.variables = variables
    data.switches = switches
    # Prevent the 'magic_number' field of System from always conflicting
    data.magic_number = $CONFIG.magic_number unless $CONFIG.magic_number == -1
    # Prevent the 'edit_map_id' field of System from conflicting
    data.edit_map_id = $CONFIG.startup_map unless $CONFIG.startup_map == -1
  elsif name == 'MapInfos'
    if $CONFIG.use_ruby?
      save_ruby(output_dir + name + '.local' + $CONFIG.export_extension, data)
    else
      save_yaml(output_dir + name + '.local' + $CONFIG.export_extension, data)
    end
    data.each do |key, map|
      map.expanded = false
      map.scroll_x = 0
      map.scroll_y = 0
      map.order = 0
    end
    # Sort the maps hash by keys to keep stable order in yaml or ruby.
    data = data.sort.to_h
  elsif data.instance_of?(RPG::Map)
    # Sort the events hash by keys to keep stable order in yaml or ruby.
    data.events = data.events.sort.to_h
  end

  temp_file = Dir.tmpdir() + '/' + name + '_fixed' + $CONFIG.export_extension

  if $CONFIG.use_ruby?
    save_ruby(temp_file, data, name: name, maps: maps)
  else
    # Dump the data to a yaml or ruby file
    unstable_file = Dir.tmpdir() + '/' + name + '_export' + $CONFIG.export_extension
    save_yaml(unstable_file, data)

    # Simplify references in yaml to avoid conflicts
    yaml_stable_ref(unstable_file, temp_file)
  end

  # Delete other maps with same number to handle map rename
  Dir.glob(output_dir + name + ' - *' + $CONFIG.export_extension).each do |file|
    begin
      # Create backup of .rb or .yaml file
      FileUtils.move(file, $CONFIG.backup_dir + '/' + now + '.' + name + $CONFIG.export_extension)
    rescue Errno::ENOENT
    end
  end
  Dir.glob(output_dir + name + $CONFIG.export_extension).each do |file|
    begin
      # Create backup of .rb or .yaml file
      FileUtils.move(file, $CONFIG.backup_dir + '/' + now + '.' + name + $CONFIG.export_extension)
    rescue Errno::ENOENT
    end
  end

  # Save map yaml or ruby
  begin
    FileUtils.move(temp_file, export_file)
  rescue Errno::ENOENT
    puts "Missing file: " + temp_file
  end

  # Update checksums
  unless import_only
    checksums[name] = FileRecord.new(name, calculate_checksum(export_file), data_checksum)
  end

  # Calculate the time to dump the .yaml or .ruby file
  dump_time = Time.now - start_time
end

def detect_cores
  begin
    return Parallel.physical_processor_count
  rescue
    return [Etc.nprocessors / 2, 1].max
  end
end

def load_yaml(export_file)
  data = nil
  File.open( export_file, "r+" ) do |input_file|
    data = YAML::unsafe_load( input_file )
  end
  return data['root']
end

def save_yaml(export_file, data)
  File.open(export_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |output_file|
    File.write(output_file, YAML::dump({'root' => data}))
  end
end

def load_ruby(export_file)
  return (RPGFactory.new).evaluate(File.read(export_file))
end

def save_ruby(export_file, data, name: nil, maps: nil)
  File.write(export_file, (RPGDumper.new(name: name, maps: maps)).dump_ruby(data))
end

def load_rxdata(data_file)
  # Change strings to utf-8 to prevent base64 encoding in yaml
  load = -> (value) {
    if value.instance_of? RPG::EventCommand
      value.parameters.each do |parameter|
        parameter.force_encoding('utf-8') if parameter.instance_of? String
      end
    elsif value.instance_of? RPG::Event
      value.name.force_encoding('utf-8')
    elsif value.instance_of? RPG::Tileset
      value.name.force_encoding('utf-8')
    elsif value.instance_of? RPG::MapInfo
      value.name.force_encoding('utf-8')
    elsif value.instance_of? Array
      value.map do |parameter|
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

def format_export_name(name, maps)
  match = name.match(/^Map0*+(?<number>[0-9]++)$/)
  return name + $CONFIG.export_extension if match.nil?
  map_name = maps.fetch(match[:number].to_i).name.gsub(/[^0-9A-Za-z ]/, '')
  return name + $CONFIG.export_extension if map_name == ''
  return name + ' - ' + map_name + $CONFIG.export_extension
end

def format_rxdata_name(name)
  match = name.match(/^(?<map>Map[0-9]++)(?: - .*)?/)
  return name + '.rxdata' if match.nil?
  return match[:map] + '.rxdata'
end

def ensure_non_duplicate_maps(files)
  data_files = files.map { |file| format_rxdata_name(File.basename(file, $CONFIG.export_extension)) }
  duplicates = data_files.tally.select { |_, count| count > 1 }.keys
  raise "Found multiple files for same map: #{duplicates}" unless duplicates.empty?
end

def calculate_checksum(file)
  return File.mtime(file).to_i.to_s + '/' + File.size(file).to_s
end

def current_commit
  git_dir = ".git"
  return nil unless Dir.exist?(git_dir)

  head_file = File.join(git_dir, "HEAD")
  head_content = File.read(head_file).strip

  if head_content.start_with?("ref: ")
    ref = head_content[5..-1]
    ref_file = File.join(git_dir, ref)
    if File.exist?(ref_file)
      return File.read(ref_file).strip
    else
      packed_refs_file = File.join(git_dir, "packed-refs")
      if File.exist?(packed_refs_file)
        regex = /^([0-9a-f]{40})\s#{Regexp.escape(ref)}$/
        File.foreach(packed_refs_file) do |line|
          match = regex.match(line)
          return match[1] if match
        end
      end
      return nil
    end
  end

  return head_content
end

def generate_patch(base_tag, password)
  require 'open3'

  if ! base_tag.nil?
    base_commit = get_base_commit_from_tag(base_tag)
    puts "Generating patch with changes since tag #{base_tag} (#{base_commit})."
  elsif $CONFIG.base_tag.nil?
    base_commit = get_base_commit_from_config
    puts "Generating patch with changes since commit #{base_commit}."
  else
    base_commit = get_base_commit_from_tag($CONFIG.base_tag)
    puts "Generating patch with changes since tag #{$CONFIG.base_tag} (#{base_commit})."
  end

  # Find files in the current working tree.
  tree = nil
  Open3.popen3('git ls-tree -r --name-only HEAD') do |stdin, stdout, stderr, waiter|
    stdin.close
    out = stdout.read
    err = stderr.read

    if waiter.value.exitstatus != 0
      puts 'Unable to get git ls-tree'
      puts out
      puts err
      exit(false)
    end

    tree = out.split("\n")
  end

  # Find all files changed between the two commits, including files that were reverted.
  # Files that were changed but deleted are included but that doesn't matter since they won't be found in current working tree.
  command = sprintf('git --no-pager log --first-parent --pretty=format: --name-status %s..HEAD | grep . | grep -v "^D" | awk \'BEGIN { FS = "\t" } { if (NF == 3) { print $3 } else { print $2 } }\' | awk \'!seen[$0]++\'', base_commit)
  files = nil
  Open3.popen3(command) do |stdin, stdout, stderr, waiter|
    stdin.close
    out = stdout.read
    err = stderr.read

    if waiter.value.exitstatus != 0
      puts 'Unable to get git log'
      puts out
      puts err
      exit(false)
    end

    files = out.split("\n")
  end

  files.select! { |file| File.fnmatch($CONFIG.patch_changed, file, File::FNM_EXTGLOB) }
  files = files.intersection(tree)

  puts "Found #{files.length} changed files."

  files = files.map do |file|
    next file unless file.start_with?($CONFIG.export_dir + '/')
    $CONFIG.data_dir + '/' + format_rxdata_name(File.basename(file, $CONFIG.export_extension))
  end

  # Find files that were deleted at any point between the two commits.
  command = sprintf('git --no-pager log --pretty=format: --name-status %s..HEAD | grep -E "^(D|R)" | awk \'BEGIN { FS="\t" } { print $2 }\' | awk \'!seen[$0]++\'', base_commit)
  deletions = nil
  Open3.popen3(command) do |stdin, stdout, stderr, waiter|
    stdin.close
    out = stdout.read
    err = stderr.read

    if waiter.value.exitstatus != 0
      puts 'Unable to get git log'
      puts out
      puts err
      exit(false)
    end

    deletions = out.split("\n")
  end

  # Write .deletions.txt file
  deletions -= tree
  deletions.select! { |file| File.fnmatch($CONFIG.patch_changed, file, File::FNM_EXTGLOB) }
  File.open(".deletions.txt", 'w') do |file|
    deletions.each do |line|
      file.puts line
    end
  end

  # Add always included files
  files.concat(Dir.glob($CONFIG.patch_always, File::FNM_EXTGLOB) - Dir.glob($CONFIG.patch_never, File::FNM_EXTGLOB))
  files.push(".deletions.txt")

  if password
    require 'seven_zip_ruby'

    File.delete('patch.7z') if File.exist?('patch.7z')

    File.open('patch.7z', 'wb') do |file|
      SevenZipRuby::Writer.open(file, { password: password }) do |sevenzip|
        files.each do |file|
          sevenzip.add_file(file)
        end
      end
    end
  else
    require 'zip'

    File.delete('patch.zip') if File.exist?('patch.zip')

    Zip::File.open('patch.zip', create: true) do |zipfile|
      files.each do |file|
        zipfile.add(file, file)
      end
    end
  end
end

def get_base_commit_from_tag(tag)
  command = ['git', 'rev-list', '-n', '1', 'tags/' + tag, '--']
  Open3.popen3(*command) do |stdin, stdout, stderr, waiter|
    stdin.close
    out = stdout.read
    err = stderr.read

    if waiter.value.exitstatus != 0
      puts 'Unable to find tag: ' + tag
      puts out
      puts err
      exit(false)
    end

    return out.strip
  end
  puts 'Unable to find tag: ' + tag
  exit(false)
end

def get_base_commit_from_config()
  if $CONFIG.base_commit.nil? || ! $CONFIG.base_commit.match(/^[a-z0-9]+$/)
    puts 'Specify the base_tag or base_commit in eevee.yaml or pass a base tag as argument.'
    exit(false)
  end

  return $CONFIG.base_commit
end

def clear_backups()
  files = Dir.entries( $CONFIG.backup_dir )
  files = files.select { |e| [".rxdata", ".yaml", ".rb"].include?(File.extname(e)) }
  files = files.select { |e| ! file_modified_since?($CONFIG.backup_dir + '/' + e, Time.now - 7*24*60*60) }
  files.each do |file|
    File.delete($CONFIG.backup_dir + '/' + file)
  end
end

def select_files(directory, masks)
  files = Dir.entries(directory)
  files = files.select { |e| match_any(e, masks) }
  return files
end

def match_any(file, masks)
  for mask in masks
    return true if File.fnmatch(mask, file, File::FNM_EXTGLOB)
  end
  return false
end

# Moves a switch or variable. Requires exporting to ruby.
def shuffle(source, target)
  if ! source.match(/^[sv][1-9][0-9]*$/) || ! target.match(/^[sv][1-9][0-9]*$/) || source[0] != target[0] || source == target
    puts 'Specify a source and target switch or variable using "s<number>" or "v<number>".'
    exit(false)
  end

  unless $CONFIG.use_ruby?
    puts 'This command can only be used with "ruby_path" configuration.'
    exit(false)
  end

  unless File.exist?($CONFIG.export_dir + "/System.rb")
    puts 'System.rb not found.'
    exit(false)
  end

  type = source[0]
  source = source[1..].to_i
  target = target[1..].to_i

  system = load_ruby($CONFIG.export_dir + "/System.rb")
  array = type == "s" ? system.switches : system.variables

  if source >= array.length
    puts 'Source does not exist.'
    exit(false)
  end

  if target >= array.length
    (array.length...target).each do |i|
      array[i] = ""
    end
  end

  array[target] = array[source]
  array[source] = ""

  files = Dir.entries($CONFIG.export_dir)
  files = files.select do |e|
    File.extname(e) == ".rb" && File.basename(e, ".rb") != "System"
  end

  files.each do |file|
    f = $CONFIG.export_dir + "/" + file
    File.write(f, File.read(f).gsub("#{type}(#{source})", "#{type}(#{target})"))
  end

  save_ruby($CONFIG.export_dir + "/System.rb", system)
end

def assets
  input_dir  = $PROJECT_DIR + $CONFIG.export_dir + '/'

  # Create the list of data files to export
  files = Dir.entries( input_dir )
  files = files.select { |e| File.extname(e) == $CONFIG.export_extension && ! e.end_with?('.local' + $CONFIG.export_extension) }
  regex = /^Map0*+(?<number>[0-9]++).*#{Regexp.quote($CONFIG.export_extension)}$/
  files.sort! do |a, b|
    a_is_map = ! a.match(regex).nil?
    b_is_map = ! b.match(regex).nil?
    next a <=> b if a_is_map && b_is_map
    next 1 if a_is_map
    next -1 if b_is_map
    next File.size(input_dir + "/" + b) <=> File.size(input_dir + "/" + a)
  end

  if files.empty?
    puts "No data files found."
    exit(false)
  end

  success = true

  Parallel.each(
    files,
    in_threads: detect_cores,
    finish: -> (file, index, result) {
      missing_assets = result[0]
      missing_events = result[1]
      conflicting_events = result[2]
      conflicting_coordinates = result[3]
      success &&= missing_assets.length == 0 && missing_events.length == 0 && conflicting_events.length == 0 && conflicting_coordinates.length == 0

      if missing_assets.length > 0
        str =  "Checked "
        str += "#{file}".ljust(50)
        str += "#{missing_assets.length} missing assets"
        puts str

        missing_assets.each do |file|
          puts "  " + file
        end

        $stdout.flush
      end

      if missing_events.length > 0
        str =  "Checked "
        str += "#{file}".ljust(50)
        str += "#{missing_events.length} missing events"
        puts str

        missing_events.each do |id|
          puts "  " + id.to_s
        end

        $stdout.flush
      end

      if conflicting_events.length > 0
        str =  "Checked "
        str += "#{file}".ljust(50)
        str += "#{conflicting_events.length} conflicting events"
        puts str

        conflicting_events.each do |id|
          puts "  " + id.to_s
        end

        $stdout.flush
      end

      if conflicting_coordinates.length > 0
        str =  "Checked "
        str += "#{file}".ljust(50)
        str += "#{conflicting_coordinates.length} conflicting coordinates"
        puts str

        conflicting_coordinates.each do |data|
          puts "  x: " + data[0][0].to_s + ", y: " + data[0][1].to_s + ", events: " + data[1].to_s
        end

        $stdout.flush
      end
    }
  ) do |file|
    factory = RPGFactory.new
    factory.evaluate(File.read(input_dir + file))
    next [factory.missing_assets, factory.missing_events, factory.conflicting_events, factory.conflicting_coordinates]
  end

  puts "No missing files detected!" if success

  exit(success)
end

def tiles
  maps = load_ruby($CONFIG.export_dir + '/MapInfos.rb')
  tilesets = load_ruby($CONFIG.export_dir + "/Tilesets.rb")
  files = Dir.entries($CONFIG.export_dir)
  files = files.select do |e|
    File.extname(e) == ".rb" && File.basename(e, ".rb").start_with?("Map") && !File.basename(e, ".rb").start_with?("MapInfos")
  end

  success = true

  i = 0
  files.each do |file|
    map = load_ruby($CONFIG.export_dir + "/" + file)
    tileset = tilesets[map.tileset_id]
    for x in 0...map.data.xsize
      for y in 0...map.data.ysize
        for z in 0...map.data.zsize
          if map.data[x, y, z] >= tileset.passages.xsize
            i += 1
            puts "invalid tile: #{x} / #{y} / #{z} is using tile #{map.data[x, y, z]} but the tileset only has tiles up to #{tileset.passages.xsize - 1} - #{file}"
            map.data[x, y, z] = 0
            success = false
          end
        end
      end
    end
    save_ruby($CONFIG.export_dir + "/" + file, map, name: File.basename(file, '.rb'), maps: maps)
  end

  if success
    puts "No incorrect tiles detected!"
  else
    puts "#{i} incorrect tiles detected"
  end

  exit(success)
end

def mapTree
  maps = load_ruby($CONFIG.export_dir + '/MapInfos.rb')
  puts dumpMaps(maps, 0, 0)
end

def dumpMaps(maps, parent_id, level)
  output = ""
  for id, map in maps
    if map.parent_id == parent_id
      output += ' ' * level * 2
      output += map.name + " (" + id.to_s + ")"
      output += "\n"
      output += dumpMaps(maps, id, level + 1)
    end
  end
  return output
end

def help(command, description)
  puts command.ljust(10, " ") + " " + description
end
