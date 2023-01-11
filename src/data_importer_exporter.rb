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
  def on_start
    # Set up the directory paths
    input_dir  = $PROJECT_DIR + $CONFIG.yaml_dir + '/'
    output_dir = $PROJECT_DIR + $CONFIG.data_dir + '/'

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
    files = files.select { |e| File.extname(e) == '.yaml' && ! e.end_with?('.local.yaml') }
    files = files.select { |f| f.index("._") != 0 }  # FIX: Ignore TextMate annoying backup files
    files.sort!

    if files.empty?
      puts_verbose "No data files to import."
      puts_verbose
      return
    end

    total_start_time = Time.now
    total_dump_time  = 0.0
    checksums = load_checksums
    ensure_non_duplicate_maps(files)

    # For each yaml file, load it and dump the objects to data file
    Parallel.each(
      files,
      in_threads: detect_cores,
      finish: -> (file, index, dump_time) {
        next if dump_time.nil?

        # Update the user on the status
        str =  "Imported "
        str += "#{file}".ljust(50)
        str += "(" + "#{index}".rjust(3, '0')
        str += "/"
        str += "#{files.size}".rjust(3, '0') + ")"
        str += "    #{dump_time} seconds"
        puts str

        total_dump_time += dump_time
      }
    ) do |file|
      import_file(file, checksums, input_dir, output_dir)
    end

    save_checksums(checksums)

    # Delete local copies of maps that were deleted by another contributor.
    maps = load_maps
    files = Dir.entries( output_dir )
    files -= $CONFIG.data_ignore_list
    files = files.select { |e| File.extname(e) == ".rxdata" }
    files = files.select do |e|
      name = File.basename(e, '.rxdata')
      match = name.match(/^Map0*+(?<number>[0-9]++)$/)
      next false if match.nil?
      next maps.fetch(match[:number].to_i, nil).nil?
    end
    files.each do |file|
      File.delete(output_dir + '/' + file)
      puts_verbose 'Deleted ' + file
    end

    # Calculate the total elapsed time
    total_elapsed_time = Time.now - total_start_time

    # Report the times
    print_separator
    puts_verbose "rxdata dump time: #{total_dump_time} seconds."
    puts_verbose "Total import time: #{total_elapsed_time} seconds."
    print_separator
    puts_verbose
  end

  def on_exit(maps, removed_files = [])
    # Set up the directory paths
    input_dir  = $PROJECT_DIR + $CONFIG.data_dir + '/'
    output_dir = $PROJECT_DIR + $CONFIG.yaml_dir + '/'

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

    total_start_time = Time.now
    total_dump_time = 0.0
    checksums = load_checksums

    # Handle deleted files
    removed_files.each do |file|
      if file.end_with?('.rxdata')
        name = File.basename(file, '.rxdata')
        yaml_file = output_dir + format_yaml_name(name, maps)
        if File.exist?(yaml_file)
          File.delete(yaml_file)
          puts_verbose 'Deleted ' + name + '.rxdata'
        end
      end
    end

    # Reload maps to correctly detect newly added ones.
    maps = load_maps

    # Create the list of data files to export
    files = Dir.entries( input_dir )
    files -= $CONFIG.data_ignore_list
    files = files.select { |e| File.extname(e) == ".rxdata" }
    files = files.select { |e| file_modified_since?(input_dir + e, $STARTUP_TIME) || ! data_file_exported?(input_dir + e) }
    files.sort!

    if files.empty?
      puts_verbose "No data files need to be exported."
      puts_verbose
      return
    end

    # For each data file, load it and dump the objects to YAML
    Parallel.each(
      files,
      in_threads: detect_cores,
      finish: -> (file, index, dump_time) {
        next if dump_time.nil?

        # Update the user on the export status
        str =  "Exported "
        str += "#{file}".ljust(30)
        str += "(" + "#{index}".rjust(3, '0')
        str += "/"
        str += "#{files.size}".rjust(3, '0') + ")"
        str += "    #{dump_time} seconds"
        puts_verbose str

        total_dump_time += dump_time
      }
    ) do |file|
      export_file(file, checksums, maps, input_dir, output_dir)
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
