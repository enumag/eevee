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
    $INPUT_DIR  = $PROJECT_DIR + '/' + $YAML_DIR + '/'
    $OUTPUT_DIR = $PROJECT_DIR + '/' + $DATA_DIR + '/'

    print_separator(true)
    puts "  RMXP Data Import"
    print_separator(true)

    # Check if the input directory exist
    if not (File.exist? $INPUT_DIR and File.directory? $INPUT_DIR)
      puts "Input directory #{$INPUT_DIR} does not exist."
      puts "Nothing to import...skipping import."
      puts
      return
    end

    # Check if the output directory exist
    if not (File.exist? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
      puts "Error: Output directory #{$OUTPUT_DIR} does not exist."
      puts "Hint: Check that the $DATA_DIR variable in paths.rb is set to the correct path."
      puts
      exit
    end

    # Create the list of data files to export
    files = Dir.entries( $INPUT_DIR )
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

    # For each yaml file, load it and dump the objects to data file
    files.each_index do |i|
      data = nil
      start_time = Time.now
      filename = File.basename(files[i], ".yaml") + ".#{$DATA_TYPE}"
      yaml_file = $INPUT_DIR + files[i]
      data_file = $OUTPUT_DIR + filename
      import_only = $IMPORT_ONLY_LIST.include?(filename)

      # Skip import if checksum matches
      if not $FORCE and not import_only and File.exist?(data_file)
        firstLine = File.open(yaml_file, &:readline)
        next if firstLine[19..18+64] == Digest::SHA256.file(data_file).hexdigest
      end
      if import_only
        next if File.file?(data_file)
      end

      # Load the data from yaml file
      File.open( yaml_file, "r+" ) do |input_file|
        data = YAML::unsafe_load( input_file )
      end

      # Dump the data to .rxdata or .rvdata file
      File.open( data_file, "w+" ) do |output_file|
        Marshal.dump( data['root'], output_file )
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

    # Calculate the total elapsed time
    total_elapsed_time = Time.now - total_start_time

    # Report the times
    print_separator
    puts_verbose "#{$DATA_TYPE} dump time: #{total_dump_time} seconds."
    puts_verbose "Total import time: #{total_elapsed_time} seconds."
    print_separator
    puts_verbose
  end

  def on_exit
    # Set up the directory paths
    $INPUT_DIR  = $PROJECT_DIR + '/' + $DATA_DIR + '/'
    $OUTPUT_DIR = $PROJECT_DIR + '/' + $YAML_DIR   + '/'

    print_separator(true)
    puts "  Data Export"
    print_separator(true)

    $STARTUP_TIME = load_startup_time || Time.now

    # Check if the input directory exist
    if not (File.exist? $INPUT_DIR and File.directory? $INPUT_DIR)
      puts "Error: Input directory #{$INPUT_DIR} does not exist."
      puts "Hint: Check that the $DATA_DIR variable in paths.rb is set to the correct path."
      exit
    end

    # Create the output directory if it doesn't exist
    if not (File.exist? $OUTPUT_DIR and File.directory? $OUTPUT_DIR)
      recursive_mkdir( $OUTPUT_DIR )
    end

    # Create the list of data files to export
    files = Dir.entries( $INPUT_DIR )
    files -= $DATA_IGNORE_LIST
    files = files.select { |e| File.extname(e) == ".#{$DATA_TYPE}" }
    files = files.select { |e| file_modified_since?($INPUT_DIR + e, $STARTUP_TIME) or not data_file_exported?($INPUT_DIR + e) } unless $FORCE == true
    files.sort!

    if files.empty?
      puts_verbose "No data files need to be exported."
      puts_verbose
      return
    end

    total_start_time = Time.now
    total_dump_time = 0.0

    # For each data file, load it and dump the objects to YAML
    files.each_index do |i|
      data = nil
      start_time = Time.now
      data_file = $INPUT_DIR + files[i]
      yaml_file = $OUTPUT_DIR + File.basename(files[i], ".#{$DATA_TYPE}") + ".yaml"
      import_only = $IMPORT_ONLY_LIST.include?(files[i])

      next if import_only and File.file?(yaml_file)

      # Load the data from rmxp's data file
      File.open( data_file, "r+" ) do |input_file|
        data = Marshal.load( input_file )
      end

      # Handle default values for the System data file
      if files[i] == "System.#{$DATA_TYPE}"
        # Prevent the 'magic_number' field of System from always conflicting
        data.magic_number = $MAGIC_NUMBER unless $MAGIC_NUMBER == -1
        # Prevent the 'edit_map_id' field of System from conflicting
        data.edit_map_id = $DEFAULT_STARTUP_MAP unless $DEFAULT_STARTUP_MAP == -1
      end

      # Dump the data to a YAML file
      checksum = Digest::SHA256.file(data_file).hexdigest
      File.open(yaml_file, File::WRONLY|File::CREAT|File::TRUNC|File::BINARY) do |output_file|
        File.write(
          output_file,
          (! import_only ? "# Checksum SHA256: #{checksum}\n" : '') + YAML::dump({'root' => data})
        )
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
        if checksum != final_checksum
          yaml = File.read(yaml_file)
          yaml[19..18+64] = final_checksum
          File.write(yaml_file, yaml)
          if $FORCE
            File.open( data_file, "w+" ) do |output_file|
              Marshal.dump( data['root'], output_file )
            end
          end
        end
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
