module Graphics
  @@window = nil
  def self.createWindow
    @@window = Window.new
    @@window.x = 0
    @@window.y = 0
    @@window.z = 100
    @@window.width = 640
    @@window.height = 480
    @@window.contents = Bitmap.new(640,480)
    @@window.back_opacity = 120
  end

  def self.disposeWindow
    @@window.dispose
  end

  def self.updateWindow
    @@window.update
  end

  def self.drawText(text)
    @@window.contents = Bitmap.new(640,480)
    height = 0
    text.split("\r\n").each{ |str|
      @@window.contents.draw_text(120,(480/2 + height),400,height + 24,str,1)
      height = height + 24
    }
    self.update
  end
end

class CMap

  def initialize(tpath = "Data/Tilesets.rxdata")
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
    @ntilesets[id] = tileset
  end
  def tilesetCount
    return @tilesets.size
  end

  def ntilesetCount
    return @ntilesets.size
  end

  def convertMap(path)
    @mapid = path.downcase.gsub("data/map","").chomp(".rxdata") if path.downcase.include?("map")

    @mapid.gsub!("patch/","") if @mapid.include?("patch/")
    @map = nil
    @nmap = nil
    #Read map
    File.open(path, "rb"){ |file|
      mdata = file.read()
      @map = Marshal.load(mdata)
      @nmap = @map.clone
    }
    #Check if it's a map or not
    return unless @map.is_a? RPG::Map
    #Get tile table from map and create tile hash
    table = @map.data.clone
    ntable = Table.new(table.xsize, table.ysize, table.zsize)
    tilehash = self.getTilehash(table)
    #Create an array with tile ids
    tileArray = Array.new
    tilehash.each_value{ |value|
      tileArray.push(value) unless tileArray.include?(value)
    }
    eventTiles = self.getEventTiles(@map.events)
    eventTiles.each{ |value|
      tileArray.push(value) unless tileArray.include?(value)
    }
    #Calculate tileset height
    tilesetwidth = 256
    tilesetheight = (tileArray.length/8.0).ceil * 32
    tilesetheight = 32 if tilesetheight == 0
    #Get tileset and it's attributes
    tileset = self.getTileset(@map.tileset_id)
    priorities = tileset.priorities
    passages = tileset.passages
    terrain_tags = tileset.terrain_tags
    #Create attributes for new tileset
    npassages = Table.new(passages.xsize)
    npriorities = Table.new(priorities.xsize)
    nterrain_tags = Table.new(terrain_tags.xsize)
    #Copy attributes for autotiles
    for i in 0...383
      npassages[i] = passages[i] unless passages[i].nil?
      npriorities[i] = priorities[i] unless priorities[i].nil?
      nterrain_tags[i] = terrain_tags[i] unless terrain_tags[i].nil?
    end
    npriorities[0] = 5

    #Create bitmaps
    oldtileset = Bitmap.new("Graphics/Tilesets/"+tileset.tileset_name)
    newtileset = Bitmap.new(tilesetwidth, tilesetheight)

    #Loop tile array to blit tiles to new tileset and
    #use a new hash to store old and new tile ids
    tindex = 384
    newtilehash = Hash.new
    tileArray.sort!

    tileArray.each { |t|
      #Copy attributes for tile
      npassages[tindex] = passages[t] unless passages[t].nil?
      npriorities[tindex] = priorities[t] unless priorities[t].nil?
      nterrain_tags[tindex] = terrain_tags[t] unless terrain_tags[t].nil?
      #Get tile coordinates for original tileset
      ox = self.getX(t)
      oy = self.getY(t)
      orect = Rect.new(ox, oy, 32, 32)
      #Get tile coordinates for new tileset
      nx = self.getX(tindex)
      ny = self.getY(tindex )
      #Blit tile to new tileset
      newtileset.blt(nx, ny, oldtileset, orect)
      #Store tile id
      newtilehash[t] = tindex
      tindex = tindex + 1
    }

    #Replace tile ids in Table and Events
    self.recreateTable(ntable, table, newtilehash)
    self.replaceTilesForEvents(@map.events, newtilehash)

    #Create new tileset
    ntileset = tileset.clone
    ntileset.id = self.tilesetCount + self.ntilesetCount
    ntileset.name = "Map"+@mapid
    ntileset.tileset_name = @mapid
    ntileset.priorities = npriorities.clone
    ntileset.passages = npassages.clone
    ntileset.terrain_tags = nterrain_tags.clone
    #Push new tileset to tilesets
    self.addToTilesets(ntileset.id, ntileset)

    #Set data and tileset_id of new map
    @nmap.data = ntable
    @nmap.tileset_id = ntileset.id
    @nmap.events = @map.events.clone

    #Save map andcreate missing directories

    Dir.mkdir("patch") unless File.exist?("patch")
    Dir.mkdir("patch/Data") unless File.exist?("patch/Data")
    path = "patch/"+path unless path.include?("patch/")
    path.gsub!("map","Map") if path.include?("map")
    File.delete(path) unless !File.file?(path)
    File.open(path, "wb"){ |f|
      f.write(Marshal.dump(@nmap))
    }
    Dir.mkdir("patch/Graphics") unless File.exist?("patch/Graphics")
    Dir.mkdir("patch/Graphics/Tilesets") unless File.exists?("patch/Graphics/Tilesets")

    #Save new tileset as png
    newtileset.save_to_file("patch/Graphics/Tilesets/"+@mapid.to_s+".png")
  end

  def writeTilesets
    path = @tilesetrx
    path = "patch/"+path unless path.include?("patch/")
    File.delete(path) unless !File.file?(path)
    File.open(path,"wb"){ |f|
      f.write(Marshal.dump(@ntilesets))
    }
  end

  #Get array of map paths
  def getMapList(dir)
    mList = Array.new
    Dir.foreach(dir){ |f|
      mList.push(dir+"/"+f) if f.downcase.include?("map")
    }
    return mList
  end

  #Get regular tiles and coordinates from Table
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

  #Get x coordinate of tile
  def getX(id)
    return ((id - 384 ) % 8 * 32).to_i
  end

  #Get y coordinate of tile
  def getY(id)
    return ((id - 384 ) / 8 * 32).to_i
  end
end

class Scene_Converter
  def main
    @sprite = Sprite.new
    begin
      @sprite.bitmap = Bitmap.new()
    rescue
    end

    Graphics.createWindow
    Graphics.transition

    Graphics.drawText("Please push Enter button to convert\r\nmaps or Escape button to exit.")
    loop do
      Graphics.update
      Input.update
      update
      if $scene != self
        break
      end
    end
    Graphics.freeze
    Graphics.disposeWindow
    begin
      @sprite.bitmap.dispose
    rescue
    end
    @sprite.dispose
  end

  def update
    Graphics.updateWindow
    if Input.trigger?(Input::C)
      command_convert
    end
    if Input.trigger?(Input::B)
      command_exit
    end
  end

  def command_convert
    Graphics.drawText("Converting Maps...")
    convertAll
    Graphics.drawText("Maps are converted.\r\nPlease push Escape button to exit.")
    loop do
      Graphics.update
      Input.update
      if Input.press?(Input::B)
        break
      end
    end
  end

  def command_exit
    $scene = nil
  end

  def convertAll
    #Loop all maps
    converter = nil
    maps = nil
    isEncrypted = false
    Dir.mkdir("patch") unless File.exist?("patch")
    Dir.foreach('.') do |filename|
      if filename.include?(".rgssad")
        Graphics.drawText("Encrypted archive is found.\r\nPlease extract rgss archive first.\r\n\r\nPlease push Escape button to exit.")
        loop do
          Graphics.update
          Input.update
          if Input.press?(Input::B)
            break
          end
        end
      else
        next
      end
    end

    converter = CMap.new
    maps = converter.getMapList("Data")


    mid = 0
    maps.each { |mapfile|
      mid = mid + 1
      Graphics.drawText("Converting maps... "+mid.to_s+"/"+maps.length.to_s)
      begin
        converter.convertMap(mapfile)
      rescue
        Graphics.drawText("Could not convert "+mapfile)
      end
    }
    converter.writeTilesets
  end
end

begin
  Graphics.freeze
  $scene = Scene_Converter.new
  while $scene != nil
    $scene.main
  end
  Graphics.transition(20)
rescue Errno::ENOENT
  filename = $!.message.sub("No such file or directory - ", "")
  print("Unable to find file #{filename}.")
end
