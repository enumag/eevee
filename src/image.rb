require 'chunky_png'

# Detects incorrect double pixels in given file or directory.
def pixels(path)
  if path.nil? || !File.exist?(path)
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

  files = Dir.entries(path).select { |f| !File.directory?(f) }

  total = 0
  files.each do |file|
    result = bad_pixels(File.join(path, file))

    if result != []
      puts "#{file} has unexpected color in #{result.length} pixels, first is #{result[0]}"
      total += 1
    end
  end

  puts "#{total} incorrect files detected"

  exit total == 0
end

def bad_pixels(file)
  img = ChunkyPNG::Image.from_file(file)
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
  return c1 == c2 && c1 == c3 && c1 == c4
end

def has_partial_transparency?(color)
  return ChunkyPNG::Color.a(color).between?(1, 254)
end

def rgba(color)
  return [
    ChunkyPNG::Color.r(img[1, 1]),
    ChunkyPNG::Color.g(img[1, 1]),
    ChunkyPNG::Color.b(img[1, 1]),
    ChunkyPNG::Color.a(img[1, 1]),
  ]
end
