require 'chunky_png'

# Detects incorrect double pixels in given file or directory.
def pixels(path)
  if path.nil?
    path = "Graphics"
  elsif !File.exist?(path)
    puts "Provide a path."
    exit false
  end

  unless File.directory?(path)
    result = bad_pixels(path)
    if result == []
      puts "#{path} has no incorrect pixels"
      exit true
    end

    result.each do |pixel|
      puts "#{pixel[0]}, #{pixel[1]}"
    end

    puts "#{path} has unexpected color in #{result.length} pixels"

    exit false
  end

  start_time = Time.now

  files = Dir.glob(File.join(path, "**/*")).select do |file|
    !File.directory?(file) && !$CONFIG.half_pixels_list.include?(file)
  end

  total = 0

  Parallel.each(
    files,
    in_threads: detect_cores,
    finish: -> (file, index, result) {
      if result != []
        puts "#{file} has unexpected color in #{result.length} pixels, first is #{result[0]}"
        total += 1
      end
    }
  ) do |file|
    next bad_pixels(file)
  end

  puts "#{total} incorrect files detected"

  total_elapsed_time = Time.now - start_time
  puts "Total time: #{total_elapsed_time} seconds."

  exit total == 0
end

def bad_pixels(file)
  begin
    img = ChunkyPNG::Image.from_file(file)
  rescue => error
    puts "Error while processing #{file}:"
    raise error
  end
  pixels = []

  (0...(img.width / 2)).each do |i|
    (0...(img.height / 2)).each do |j|
      x = i * 2
      y = j * 2
      expected_color = img[x, y]
      unless same_colors?(expected_color, img[x + 1, y], img[x, y + 1], img[x + 1, y + 1])
        pixels.push [x, y]
      end
      # if has_partial_transparency?(expected_color)
      #   pixels.push [i * 2, j * 2]
      # end
    end
  end

  return pixels
end

def same_colors?(c1, c2, c3, c4)
  return same_color?(c1, c2) && same_color?(c1, c3) && same_color?(c1, c4)
end

def same_color?(c1, c2)
  return c1 == c2 || (ChunkyPNG::Color.a(c1) == 0 && ChunkyPNG::Color.a(c2) == 0)
end

def has_partial_transparency?(color)
  return ChunkyPNG::Color.a(color).between?(1, 254)
end

def rgba(color)
  return [
    ChunkyPNG::Color.r(color),
    ChunkyPNG::Color.g(color),
    ChunkyPNG::Color.b(color),
    ChunkyPNG::Color.a(color),
  ]
end
