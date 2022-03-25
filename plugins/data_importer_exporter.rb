#===============================================================================
# Filename:    data_importer_exporter.rb
#
# Developer:   Raku (rakudayo@gmail.com)
#              XXXX
#
# Description: This file contains a plugin for the RMXP Plugin System which 
#  automatically exports all data files (except Scripts) to plain text YAML
#  files which can be versioned using a versioning system such as Subversion or 
#  Mercurial.  When the system shuts down, all data is output into YAML and when the
#  system is started again, the YAML files are read back into the original data files.
#===============================================================================

class DataImporterExporter
  def initialize
    super
  end

  def on_start
    # Set up the directory paths
    input_dir  = $PROJECT_DIR + '/' + $CONFIG.yaml_dir + '/'
    output_dir = $PROJECT_DIR + '/' + $CONFIG.data_dir + '/'

    print_separator(true)
    puts "  RMXP Data Import"
    print_separator(true)

    # Check if the input directory exist
    if not (File.exist? input_dir and File.directory? input_dir)
      puts "Input directory #{input_dir} does not exist."
      puts "Nothing to import...skipping import."
      puts
      return
    end

    # Check if the output directory exist
    if not (File.exist? output_dir and File.directory? output_dir)
      puts "Error: Output directory #{output_dir} does not exist."
      puts "Hint: Check that the $CONFIG.data_dir variable in paths.rb is set to the correct path."
      puts
      exit
    end

    # Create the list of data files to export
    files = Dir.entries( input_dir )
    files = files.select { |e| File.extname(e) == '.yaml' }
    files = files.select { |f| f.index("._") != 0 }  # FIX: Ignore TextMate annoying backup files
    files.sort!

    if files.empty?
      puts_verbose "No data files to import."
      puts_verbose
      return
    end

    total_start_time = Time.now
    total_dump_time  = 0.0
    checksums = load_checksums()

    # For each yaml file, load it and dump the objects to data file
    files.each_index do |i|
      data = nil
      start_time = Time.now
      name = File.basename(files[i], ".yaml")
      record = checksums[name]
      filename = name + ".rxdata"
      yaml_file = input_dir + files[i]
      data_file = output_dir + filename
      import_only = $CONFIG.import_only_list.include?(filename)
      yaml_checksum = Digest::SHA256.file(yaml_file).hexdigest
      data_checksum = File.exist?(data_file) ? Digest::SHA256.file(data_file).hexdigest : nil

      # Skip import if checksum matches
      next if skip_file(record, data_checksum, yaml_checksum, import_only)

      # Load the data from yaml file
      File.open( yaml_file, "r+" ) do |input_file|
        data = YAML::unsafe_load( input_file )
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
      total_dump_time += dump_time

      # Update the user on the status
      str =  "Imported "
      str += "#{files[i]}".ljust(30)
      str += "(" + "#{i+1}".rjust(3, '0')
      str += "/"
      str += "#{files.size}".rjust(3, '0') + ")"
      str += "    #{dump_time} seconds"
      puts_verbose str
    end

    save_checksums(checksums)

    # Calculate the total elapsed time
    total_elapsed_time = Time.now - total_start_time

    # Report the times
    print_separator
    puts_verbose "rxdata dump time: #{total_dump_time} seconds."
    puts_verbose "Total import time: #{total_elapsed_time} seconds."
    print_separator
    puts_verbose
  end

  def on_exit
    # Set up the directory paths
    input_dir  = $PROJECT_DIR + '/' + $CONFIG.data_dir + '/'
    output_dir = $PROJECT_DIR + '/' + $CONFIG.yaml_dir   + '/'

    print_separator(true)
    puts "  Data Export"
    print_separator(true)

    $STARTUP_TIME = load_startup_time || Time.now

    # Check if the input directory exist
    if not (File.exist? input_dir and File.directory? input_dir)
      puts "Error: Input directory #{input_dir} does not exist."
      puts "Hint: Check that the $CONFIG.data_dir variable in paths.rb is set to the correct path."
      exit
    end

    # Create the output directory if it doesn't exist
    if not (File.exist? output_dir and File.directory? output_dir)
      recursive_mkdir( output_dir )
    end

    # Create the list of data files to export
    files = Dir.entries( input_dir )
    files -= $CONFIG.data_ignore_list
    files = files.select { |e| File.extname(e) == ".rxdata" }
    files = files.select { |e| file_modified_since?(input_dir + e, $STARTUP_TIME) or not data_file_exported?(input_dir + e) } unless $FORCE == true
    files.sort!

    if files.empty?
      puts_verbose "No data files need to be exported."
      puts_verbose
      return
    end

    total_start_time = Time.now
    total_dump_time = 0.0
    checksums = load_checksums()

    # For each data file, load it and dump the objects to YAML
    files.each_index do |i|
      data = nil
      start_time = Time.now
      name = File.basename(files[i], ".rxdata")
      record = checksums[name]
      data_file = input_dir + files[i]
      yaml_file = output_dir + name + ".yaml"
      import_only = $CONFIG.import_only_list.include?(files[i])
      yaml_checksum = File.exist?(yaml_file) ? Digest::SHA256.file(yaml_file).hexdigest : nil
      data_checksum = Digest::SHA256.file(data_file).hexdigest

      # Skip import if checksum matches
      next if skip_file(record, data_checksum, yaml_checksum, import_only)

      # Load the data from rmxp's data file
      File.open( data_file, "r+" ) do |input_file|
        data = Marshal.load( input_file )
      end

      # Handle default values for the System data file
      if files[i] == "System.rxdata"
        # Prevent the 'magic_number' field of System from always conflicting
        data.magic_number = $CONFIG.magic_number unless $CONFIG.magic_number == -1
        # Prevent the 'edit_map_id' field of System from conflicting
        data.edit_map_id = $CONFIG.startup_map unless $CONFIG.startup_map == -1
      end

      # Dump the data to a YAML file
      File.open(yaml_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |output_file|
        File.write(output_file, YAML::dump({'root' => data}))
      end

      # Dirty workaround to sort the keys in yaml
      temp_file = Dir.tmpdir() + '/temp.yaml'
      command = 'START /B /WAIT /D"' + $PROJECT_DIR + '" yq.exe "sort_keys(..)" "' + yaml_file + '" > "' + temp_file + '"'
      system(command)
      yaml_stable_ref(temp_file, yaml_file)

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
      total_dump_time += dump_time
 
      # Update the user on the export status
      str =  "Exported "
      str += "#{files[i]}".ljust(30)
      str += "(" + "#{i+1}".rjust(3, '0')
      str += "/"
      str += "#{files.size}".rjust(3, '0') + ")"
      str += "    #{dump_time} seconds"
      puts_verbose str
    end

    save_checksums(checksums)

    # Calculate the total elapsed time
    total_elapsed_time = Time.now - total_start_time
 
    # Report the times
    print_separator
    puts_verbose "YAML dump time: #{total_dump_time} seconds."
    puts_verbose "Total export time: #{total_elapsed_time} seconds."
    print_separator
    puts_verbose
  end
end
