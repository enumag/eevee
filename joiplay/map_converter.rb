# Base version extracted from Scripts.rxdata contained in Wine version of JoiPlay's MapConverter (https://www.patreon.com/posts/36096923).

#Bitmap saver from Cacao
module Zlib
  class PngFile
    def self.make_png(bitmap, mode = 0)
      @bitmap, @mode = bitmap, mode
      return make_header + make_ihdr + make_idat_and_png_data + make_iend
    end
    def self.make_header
      # (HTJ)PNG(CR)(LF)(SUB)(LF), the common PNG header
      return [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack('C*')
    end
    def self.make_ihdr
      ih_size               = [13].pack('N')
      ih_sign               = 'IHDR'
      ih_width              = [@bitmap.width].pack('N')
      ih_height             = [@bitmap.height].pack('N')
      ih_bit_depth          = [8].pack('C')
      ih_color_type         = [6].pack('C')
      ih_compression_method = [0].pack('C')
      ih_filter_method      = [0].pack('C')
      ih_interlace_method   = [0].pack('C')
      string = ih_sign + ih_width + ih_height + ih_bit_depth + ih_color_type +
        ih_compression_method + ih_filter_method + ih_interlace_method
      ih_crc = [Zlib.crc32(string)].pack('N')
      return ih_size + string + ih_crc
    end
    def self.make_idat_and_png_data
      # IDAT, part of the header data
      header  = "\x49\x44\x41\x54"
      # Convert bitmap to PNG data
      data    = @mode == 0 ? make_bitmap_data0 : make_bitmap_data1
      # Compress the data
      data    = Zlib::Deflate.deflate(data, 8)
      # CRC32 hash for IDAT and image data
      crc     = [Zlib.crc32(header + data)].pack('N')
      # Size of image data
      size    = [data.length].pack('N')
      return size + header + data + crc
    end
    def self.make_bitmap_data0
      t_Fx = 0
      w = @bitmap.width
      h = @bitmap.height
      data = []
      s = []
      for y in 0...h
        data.push(0)
        for x in 0...w
          t_Fx += 1
          if t_Fx % 10000 == 0
            # for every 10k pixels processed
            if t_Fx % 100000 == 0
              # for every 100k pixels processed
              s += data
              data.clear
            end
          end
          color = @bitmap.get_pixel(x, y)
          data.push(color.red, color.green, color.blue, color.alpha)
        end
      end
      s = (s+data).pack('C*')
      data.clear
      return s
    end
    def self.make_bitmap_data1
      w = @bitmap.width
      h = @bitmap.height
      data = []
      for y in 0...h
        data.push(0)
        for x in 0...w
          color = @bitmap.get_pixel(x, y)
          data.push(color.red, color.green, color.blue, color.alpha)
        end
      end
      return data.pack('C*')
    end
    def self.make_iend
      ie_size = [0].pack('N')
      ie_sign = 'IEND'
      ie_crc  = [Zlib.crc32(ie_sign)].pack('N')
      return ie_size + ie_sign + ie_crc
    end
  end
end

class Bitmap
  def make_png(name = 'like', path = '', mode = 0)
    filepath = path + name + '.png'
    pngdata = Zlib::PngFile.make_png(self, mode)
    File.delete(filepath) if File.file?(filepath)
    f = File.open(filepath, 'wb')
    f.write(pngdata)
    f.close
  end
end

class CMap

  def initialize(tpath)
    @tilesetrx = tpath
    @tilesets = nil
    @ntilesets = nil
    self.readTilesets
  end

  attr_accessor :tilesetrx
  attr_accessor :tilesets
  attr_accessor :ntilesets

  def readTilesets
    File.open(@tilesetrx, "rb"){ |file|
      tdata = file.read()
      @tilesets = Marshal.load(tdata)
      @ntilesets = @tilesets.clone
    }
  end

  def getTileset(id)
    return @tilesets[id]
  end

  def addToTilesets(id, tileset)
    validateTable(tileset.passages)
    validateTable(tileset.priorities)
    validateTable(tileset.terrain_tags)
    @ntilesets[id] = tileset
  end

  def nextTilesetID(mapid)
    return @tilesets.size.ceil(-3) + mapid
  end

  def validateTable(table)
    if table.data.length != table.xsize * table.ysize * table.zsize
      raise "incorrect table data size, expected: "+table.xsize.to_s+" * "+table.ysize.to_s+" * "+table.zsize.to_s+" = "+(table.xsize * table.ysize * table.zsize).to_s+", actual "+table.data.length.to_s
    end
    table.data.each_with_index do |v, i| v
      raise "nil in table index "+i.to_s if v.nil?
    end
  end

  def convertMap(path)
    mapid = path.downcase.gsub("data/map","").chomp(".rxdata") if path.downcase.include?("map")

    mapid.gsub!("patch/","") if mapid.include?("patch/")
    map = nil
    nmap = nil
    # Read map
    File.open(path, "rb"){ |file|
      mdata = file.read()
      map = Marshal.load(mdata)
      nmap = map.clone
    }
    # Check if it's a map or not
    return unless map.is_a? RPG::Map
    # Get tile table from map and create tile hash
    table = map.data.clone
    ntable = Table.new(table.xsize, table.ysize, table.zsize)
    tilehash = self.getTilehash(table)
    # Create an array with tile ids
    tileArray = Array.new
    tilehash.each_value{ |value|
      tileArray.push(value) unless tileArray.include?(value)
    }
    eventTiles = self.getEventTiles(map.events)
    eventTiles.each{ |value|
      tileArray.push(value) unless tileArray.include?(value)
    }
    # Calculate tileset height
    tilesetwidth = 256
    tilesetheight = (tileArray.length/8.0).ceil * 32
    tilesetheight = 32 if tilesetheight == 0
    # Get tileset and it's attributes
    tileset = self.getTileset(map.tileset_id)
    priorities = tileset.priorities
    passages = tileset.passages
    terrain_tags = tileset.terrain_tags
    # Create attributes for new tileset
    npassages = Table.new(passages.xsize)
    npriorities = Table.new(priorities.xsize)
    nterrain_tags = Table.new(terrain_tags.xsize)
    # Copy attributes for autotiles
    for i in 0...384
      npassages[i] = passages[i] unless passages[i].nil?
      npriorities[i] = priorities[i] unless priorities[i].nil?
      nterrain_tags[i] = terrain_tags[i] unless terrain_tags[i].nil?
    end
    npriorities[0] = 5

    # Create bitmaps
    oldtileset = Bitmap.new("Graphics/Tilesets/"+tileset.tileset_name+".png")
    newtileset = Bitmap.new(tilesetwidth, tilesetheight)

    # Loop tile array to blit tiles to new tileset and
    # use a new hash to store old and new tile ids
    tindex = 384
    newtilehash = Hash.new
    tileArray.sort!

    tileArray.each { |t|
      # Copy attributes for tile
      npassages[tindex] = passages[t] unless passages[t].nil?
      npriorities[tindex] = priorities[t] unless priorities[t].nil?
      nterrain_tags[tindex] = terrain_tags[t] unless terrain_tags[t].nil?
      # Get tile coordinates for original tileset
      ox = self.getX(t)
      oy = self.getY(t)
      orect = Rect.new(ox, oy, 32, 32)
      # Get tile coordinates for new tileset
      nx = self.getX(tindex)
      ny = self.getY(tindex )
      # Blit tile to new tileset
      newtileset.blt(nx, ny, oldtileset, orect)
      # Store tile id
      newtilehash[t] = tindex
      tindex = tindex + 1
    }

    # Replace tile ids in Table and Events
    self.recreateTable(ntable, table, newtilehash)
    self.replaceTilesForEvents(map.events, newtilehash)

    # Create new tileset
    ntileset = tileset.clone
    ntileset.id = self.nextTilesetID(mapid.to_i)
    ntileset.name = "Map"+mapid
    ntileset.tileset_name = mapid
    ntileset.priorities = npriorities
    ntileset.passages = npassages
    ntileset.terrain_tags = nterrain_tags
    # Push new tileset to tilesets
    self.addToTilesets(ntileset.id, ntileset)

    # Set data and tileset_id of new map
    nmap.data = ntable
    nmap.tileset_id = ntileset.id
    nmap.events = map.events.clone

    # Save map and create missing directories
    Dir.mkdir("patch") unless File.exist?("patch")
    Dir.mkdir("patch/Data") unless File.exist?("patch/Data")
    path = "patch/"+path unless path.include?("patch/")
    path.gsub!("map","Map") if path.include?("map")
    File.delete(path) if File.file?(path)
    File.open(path, "wb"){ |f|
      Marshal.dump(nmap, f)
    }
    Dir.mkdir("patch/Graphics") unless File.exist?("patch/Graphics")
    Dir.mkdir("patch/Graphics/Tilesets") unless File.exist?("patch/Graphics/Tilesets")

    # Save new tileset as png
    newtileset.make_png(mapid, "patch/Graphics/Tilesets/")
  end

  def writeTilesets
    path = "patch/"+@tilesetrx
    File.delete(path) if File.file?(path)
    File.open(path,"wb"){ |f|
      Marshal.dump(@ntilesets, f)
    }
  end

  # Get array of map paths
  def getMapList(dir)
    files = Dir.entries(dir)
    files = files.select { |e| File.extname(e) == ".rxdata" }
    files = files.select do |e|
      name = File.basename(e, '.rxdata')
      match = name.match(/^Map0*+(?<number>[0-9]++)$/)
      next ! match.nil?
    end
    files.sort!
    return files
  end

  # Get regular tiles and coordinates from Table
  def getTilehash(table)
    xsize = table.xsize
    ysize = table.ysize
    zsize = table.zsize
    tilehash = Hash.new
    for z in 0...zsize
      for y in 0...ysize
        for x in 0...xsize
          id = table[x, y, z]
          if id.is_a? Integer
            next if id < 384
            cor = [x,y,z]
            tilehash[cor] = id
          end
        end
      end
    end
    return tilehash
  end

  def getEventTiles(events)
    tiles = Array.new
    events.each_value{|event|
      event.pages.each{|page|
        graphic = page.graphic
        id = graphic.tile_id
        tiles.push(id) unless id == 0
      }
    }
    return tiles
  end

  def recreateTable(new, old, hash)
    for z in 0...old.zsize
      for y in 0...old.ysize
        for x in 0...old.xsize
          oid = old[x, y, z]
          if oid.is_a? Integer
            if oid < 384
              new[x,y,z] = old[x,y,z]
            else
              hid = hash[oid]
              if hid.is_a? Integer
                new[x,y,z] = hid
              end
            end
          end
        end
      end
    end
  end

  def replaceTilesForEvents(events, hash)
    events.each_value{|event|
      event.pages.each{|page|
        graphic = page.graphic
        id = graphic.tile_id
        graphic.tile_id = hash[id] unless id == 0
      }
    }
  end

  # Get x coordinate of tile
  def getX(id)
    return ((id - 384 ) % 8 * 32).to_i
  end

  # Get y coordinate of tile
  def getY(id)
    return ((id - 384 ) / 8 * 32).to_i
  end
end

def convertAll
  Dir.mkdir("patch") unless File.exist?("patch")

  converter = CMap.new("Data/Tilesets.rxdata")
  maps = converter.getMapList("Data")

  Parallel.each(
    maps,
    in_threads: Parallel.physical_processor_count,
    finish: -> (file, index, result) {
      str =  "Converted "
      str += "#{file}".ljust(50)
      str += "(" + "#{index}".rjust(3, '0')
      str += "/"
      str += "#{maps.size}".rjust(3, '0') + ")"
      puts str
    }
  ) do |file|
    converter.convertMap("Data/#{file}")
  end

  puts "Writing tilesets..."
  converter.writeTilesets
  puts "Done"
end
