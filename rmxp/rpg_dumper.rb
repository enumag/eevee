class RPGDumper
  def dump_ruby(object)
    case object
    when RPG::Map
      return map(object, 0)
    end
  end

  DEFAULT_AUDIO = Marshal.dump(RPG::AudioFile.new)
  DEFAULT_BGS = Marshal.dump(RPG::AudioFile.new("", 80))
  DEFAULT_CONDITION = Marshal.dump(RPG::Event::Page::Condition.new)
  DEFAULT_GRAPHIC = Marshal.dump(RPG::Event::Page::Graphic.new)
  DEFAULT_COMMAND = Marshal.dump(RPG::EventCommand.new)
  DEFAULT_ROUTE = Marshal.dump(RPG::MoveRoute.new)
  DEFAULT_MOVE = Marshal.dump(RPG::MoveCommand.new)
  DEFAULT_PAGE = Marshal.dump(RPG::Event::Page.new)

  def map(map, level)
    value = "map(\n"
    value += indent(level + 1) + "tileset_id: " + map.tileset_id.inspect + ",\n" if map.tileset_id != 1
    value += indent(level + 1) + "autoplay_bgm: " + map.autoplay_bgm.inspect + ",\n" if map.autoplay_bgm != false
    value += indent(level + 1) + "bgm: " + audio(map.bgm, level + 1) + ",\n" if Marshal.dump(map.bgm) != DEFAULT_AUDIO
    value += indent(level + 1) + "autoplay_bgs: " + map.autoplay_bgs.inspect + ",\n" if map.autoplay_bgs != false
    value += indent(level + 1) + "bgs: " + audio(map.bgs, level + 1) + ",\n" if Marshal.dump(map.bgs) != DEFAULT_BGS
    raise "non-empty map encounter_list" if map.encounter_list != []
    value += indent(level + 1) + "encounter_step: " + map.encounter_step.inspect + ",\n" if map.encounter_step != 30
    value += indent(level + 1) + "events: [\n\n"
    map.events.each do |key, event|
      value += indent(level + 2) + event(event, level + 2) + ",\n\n"
    end
    value += indent(level + 1) + "],\n"
    value += indent(level + 1) + "data: " + table(map.data, level + 1) + ",\n"
    value += indent(level) + ")"
    return value
  end

  def audio(audio, level)
    value = "audio("
    parameters = []
    parameters.append "name: " + audio.name.inspect if audio.name != ""
    parameters.append "volume: " + audio.volume.inspect if audio.volume != 100
    parameters.append "pitch: " + audio.pitch.inspect if audio.pitch != 100
    value += parameters.join(", ")
    value += ")"
    return value
  end

  def table(table, level)
    value = "table(\n"
    value += indent(level + 1) + "x: " + table.xsize.inspect + ",\n"
    value += indent(level + 1) + "y: " + table.ysize.inspect + ",\n" if table.ysize > 1
    value += indent(level + 1) + "z: " + table.zsize.inspect + ",\n" if table.zsize > 1

    # Method 1 - fastest solution but not pretty
    # value += indent(level + 1) + "data: " + table.data.inspect + ",\n"

    # Method 2 - very slow but nice result
    # value += indent(level + 1) + "data: [\n"
    # i = 0
    # table.data.each do |cell|
    #   i += 1
    #   if i % table.xsize == 1
    #     value += indent(level + 2)
    #   end
    #   value += cell.to_s.rjust(4) + ","
    #   if i % table.xsize == 0
    #     value += "\n"
    #     if i % (table.xsize * table.ysize) == 0
    #       value += "\n" if i != table.data.count
    #     end
    #   else
    #     value += " "
    #   end
    # end
    # value += indent(level + 1) + "],\n"

    # Method 3 - still fast, at least it's separated by layer
    # value += indent(level + 1) + "data: [\n"
    # (0...table.zsize).each do |z|
    #   value += indent(level + 2) + "*" + table.data[z * table.xsize * table.ysize, table.xsize * table.ysize].inspect + ",\n"
    # end
    # value += indent(level + 1) + "],\n"

    # Method 4 - speed still fine, result without padding
    # value += indent(level + 1) + "data: [\n"
    # start = 0
    # (0...table.zsize).each do
    #   (0...table.ysize).each do
    #     value += indent(level + 2) + "*" + table.data[start, table.xsize].inspect + ",\n"
    #     start += table.xsize
    #   end
    #   value += "\n"
    # end
    # value += indent(level + 1) + "],\n"

    # Method 5 - optimized speed, result with padding
    value += indent(level + 1) + "data: [\n"
    start = 0
    (0...table.zsize).each do
      (0...table.ysize).each do
        value += (indent(level + 2) + table.data[start, table.xsize].inspect[1..-2] + ',').
          gsub(/ ([0-9]{1}),/, "    \\1,").
          gsub(/ ([0-9]{2}),/, "   \\1,").
          gsub(/ ([0-9]{3}),/, "  \\1,") + "\n"
        start += table.xsize
      end
      value += "\n"
    end
    value += indent(level + 1) + "],\n"

    value += indent(level) + ")"
    return value
  end

  def event(event, level)
    value = "event(\n"
    value += indent(level + 1) + "id: " + event.id.inspect + ",\n"
    value += indent(level + 1) + "name: " + event.name.inspect + ",\n"
    value += indent(level + 1) + "x: " + event.x.inspect + ",\n"
    value += indent(level + 1) + "y: " + event.y.inspect + ",\n"

    if event.pages.count > 1 || Marshal.dump(event.pages[0]) != DEFAULT_PAGE
      event.pages.each_with_index do |page, i|
        value += indent(level + 1) + "page_" + i.to_s + ": " + page(page, level + 1) + ",\n"
      end
    end

    value += indent(level) + ")"
    return value
  end

  def page(page, level)
    return "page" if Marshal.dump(page) == DEFAULT_PAGE

    value = "page(\n"

    if Marshal.dump(page.condition) != DEFAULT_CONDITION
      value += indent(level + 1) + "switch1_valid: " + page.condition.switch1_valid.inspect + ",\n" if page.condition.switch1_valid == false && page.condition.switch1_id != 1
      value += indent(level + 1) + "switch1: switch(" + page.condition.switch1_id.inspect + "),\n" if page.condition.switch1_id != 1
      value += indent(level + 1) + "switch2_valid: " + page.condition.switch2_valid.inspect + ",\n" if page.condition.switch2_valid == false && page.condition.switch2_id != 1
      value += indent(level + 1) + "switch2: switch(" + page.condition.switch2_id.inspect + "),\n" if page.condition.switch2_id != 1
      value += indent(level + 1) + "variable_valid: " + page.condition.variable_valid.inspect + ",\n" if page.condition.variable_valid == false && page.condition.variable_id != 1
      value += indent(level + 1) + "variable: variable(" + page.condition.variable_id.inspect + "),\n" if page.condition.variable_id != 1
      value += indent(level + 1) + "at_least: " + page.condition.variable_value.inspect + ",\n" if page.condition.variable_value != 0
      value += indent(level + 1) + "self_switch_valid: " + page.condition.self_switch_valid.inspect + ",\n" if page.condition.self_switch_valid == false && page.condition.self_switch_ch != "A"
      value += indent(level + 1) + "self_switch: " + page.condition.self_switch_ch.inspect + ",\n" if page.condition.self_switch_ch != "A" || page.condition.self_switch_valid
    end

    value += indent(level + 1) + "graphic: " + graphic(page.graphic, level + 1) + ",\n" if Marshal.dump(page.graphic) != DEFAULT_GRAPHIC
    value += indent(level + 1) + "move_type: " + RPGFactory::EVENT_MOVE_TYPE[page.move_type].inspect + ",\n" if page.move_type != 0
    value += indent(level + 1) + "move_speed: " + page.move_speed.inspect + ",\n" if page.move_speed != 3
    value += indent(level + 1) + "move_frequency: " + page.move_frequency.inspect + ",\n" if page.move_frequency != 3
    value += indent(level + 1) + "move_route: " + route(page.move_route, level + 1) + ",\n" if Marshal.dump(page.move_route) != DEFAULT_ROUTE
    value += indent(level + 1) + "walk_anime: " + page.walk_anime.inspect + ",\n" if page.walk_anime != true
    value += indent(level + 1) + "step_anime: " + page.step_anime.inspect + ",\n" if page.step_anime != false
    value += indent(level + 1) + "direction_fix: " + page.direction_fix.inspect + ",\n" if page.direction_fix != false
    value += indent(level + 1) + "through: " + page.through.inspect + ",\n" if page.through != false
    value += indent(level + 1) + "always_on_top: " + page.always_on_top.inspect + ",\n" if page.always_on_top != false
    value += indent(level + 1) + "trigger: " + RPGFactory::EVENT_TRIGGER[page.trigger].inspect + ",\n" if page.trigger != 0

    commands = page.list.clone
    last = commands.pop
    raise "unexpected last event command" if Marshal.dump(last) != DEFAULT_COMMAND
    if page.list.count > 1
      value += indent(level + 1) + "list: [\n"
      value += command_list(commands, level + 2)
      value += indent(level + 1) + "],\n"
    end

    value += indent(level) + ")"
    return value
  end

  def command_list(commands, level)
    value = ""
    i = 0
    while i < commands.count
      command = commands[i]
      case command.code

      # Flow control commands
      when 0 # block end
        level -= 2
        value += indent(level + 1) + "],\n"
        # Band-aid for a rare case of two code 0 commands.
        parts = collect(commands, i + 1, 0)
        i += parts.count
      when 102 # show choices
        value += command_show_choices(command, level)
      when 402 # show choices - when
        if commands[i + 1].code == 0
          i += 1
        else
          value += command_when(command, level)
          level += 2
        end
      when 403 # show choices - when cancel
        if commands[i + 1].code == 0
          i += 1
        else
          value += command_when_cancel(command, level)
          level += 2
        end
      when 111 # if
        value += command_condition(command, level)
        if commands[i + 1].code == 0
          i += 1
        else
          value += indent(level + 1) + "then: [\n"
          level += 2
        end
      when 112 # loop
        value += command_loop(command, level)
        value += indent(level + 1) + "commands: ["
        if commands[i + 1].code == 0
          value += "],"
          i += 1
        else
          level += 2
        end
        value += "\n"
      when 411 # else
        value += indent(level + 1) + "else: ["
        if commands[i + 1].code == 0
          value += "],"
          i += 1
        else
          level += 2
        end
        value += "\n"
      when 404, 412, 413, 604 # show choices end, branch end, loop end, battle end
        value += indent(level) + "),\n"

      # Control flow battle commands
      when 301
        value += command_battle(command, level)
        level += 2
      when 601
        value += command_win(command, level)
        level += 2
      when 602
        value += command_escape(command, level)
        level += 2
      when 603
        value += command_lose(command, level)
        level += 2

      # Command groups
      when 101 # text
        parts = collect(commands, i + 1, 401)
        i += parts.count
        parts.unshift(command)
        value += command_text(parts, level)
      when 355 # script
        parts = collect(commands, i + 1, 655)
        i += parts.count
        parts.unshift(command)
        value += command_script(parts, level)
      when 209 # move route
        parts = collect(commands, i + 1, 509)
        i += parts.count
        value += command_move_route(command, level)

      # Other commands
      when 103 # input number
        value += command_input_number(command, level)
      when 104 # change text options
        value += command_simple("change_text_options", 2, command, level)
      when 105 # button input processing
        value += command_button_input_processing(command, level)
      when 106 # wait
        value += command_simple("wait", 1, command, level)
      when 113 # break loop
        value += command_simple("break_loop", 0, command, level)
      when 115 # break loop
        value += command_simple("exit_event_processing", 0, command, level)
      when 116 # erase event
        value += command_simple("erase_event", 0, command, level)
      when 117 # call common event
        value += command_simple("call_common_event", 1, command, level)
      when 118 # label
        value += command_simple("label", 1, command, level)
      when 119 # jump to label
        value += command_simple("jump_label", 1, command, level)
      when 121 # control switches
        value += command_switch(command, level)
      when 122 # control variables
        value += command_variable(command, level)
      when 123 # control self switch
        value += command_self_switch(command, level)
      when 125 # change gold
        value += command_change_gold(command, level)
      when 131 # change windowskin
        value += command_simple("change_windowskin", 1, command, level)
      when 201 # transfer player
        value += command_transfer_player(command, level)
      when 202 # set event location
        value += command_event_location(command, level)
      when 203 # scroll map
        value += command_scroll_map(command, level)
      when 205 # change for color tone
        value += command_change_fog_tone(command, level)
      when 210 # wait for move's completion
        value += command_simple("wait_completion", 0, command, level)
      when 223 # change screen color tone
        value += command_change_tone(command, level)
      when 224 # screen flash
        value += command_screen_flash(command, level)
      when 234 # change picture tone
        value += command_change_picture_tone(command, level)
      when 132 # change battle bgm
        value += command_audio("battle_bgm", command, level)
      when 133 # change battle me
        value += command_audio("battle_me", command, level)
      when 241 # play bgm
        value += command_audio("play_bgm", command, level)
      when 245 # play bgs
        value += command_audio("play_bgs", command, level)
      when 249 # play me
        value += command_audio("play_me", command, level)
      when 250 # play se
        value += command_audio("play_se", command, level)

      # Unknown command
      else
        value += command(command, level)
      end
      i += 1
    end
    return value
  end

  def collect(commands, index, code)
    return [] if commands.length == index
    parts = []
    while commands[index].code == code
      parts.append(commands[index])
      index += 1
      break if commands.length == index
    end
    return parts
  end

  def command_text(commands, level)
    if commands.count == 1
      value = indent(level) + "text("
      raise "unexpected command parameters" if commands[0].parameters.count != 1
      value += commands[0].parameters[0].inspect + "),\n"
      return value
    end

    value = indent(level) + "*text(\n"
    commands.each do |command|
      raise "unexpected command parameters" if command.parameters.count != 1
      value += indent(level + 1) + command.parameters[0].inspect + ",\n"
    end
    value += indent(level) + "),\n"
    return value
  end

  def command_script(commands, level)
    if commands.count == 1
      value = indent(level) + "script("
      raise "unexpected command parameters" if commands[0].parameters.count != 1
      value += commands[0].parameters[0].inspect + "),\n"
      return value
    end

    value = indent(level) + "*script(\n"
    value += indent(level + 1) + "<<~CODE\n"
      commands.each do |command|
      raise "unexpected command parameters" if command.parameters.count != 1
      value += indent(level + 1) + command.parameters[0] + "\n"
    end
    value += indent(level + 1) + "CODE\n"
    value += indent(level) + "),\n"
    return value
  end

  def command_scroll_map(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "scroll_map("
    value += "direction: " + RPGFactory::DIRECTION[command.parameters[0]].inspect + ", "
    value += "distance: " + command.parameters[1].inspect + ", "
    value += "speed: " + command.parameters[2].inspect
    value += "),\n"
    return value
  end

  def command_change_picture_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "change_picture_tone("
    value += "number: " + command.parameters[0].inspect + ", "
    value += "red: " + command.parameters[1].red.to_i.inspect + ", "
    value += "green: " + command.parameters[1].green.to_i.inspect + ", "
    value += "blue: " + command.parameters[1].blue.to_i.inspect + ", "
    value += "gray: " + command.parameters[1].gray.to_i.inspect + ", " if command.parameters[1].gray != 0.0
    value += "frames: " + command.parameters[2].inspect
    value += "),\n"
    return value
  end

  def command_change_fog_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "change_fog_tone("
    value += "red: " + command.parameters[0].red.to_i.inspect + ", "
    value += "green: " + command.parameters[0].green.to_i.inspect + ", "
    value += "blue: " + command.parameters[0].blue.to_i.inspect + ", "
    value += "gray: " + command.parameters[0].gray.to_i.inspect + ", " if command.parameters[0].gray != 0.0
    value += "frames: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_change_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "change_tone("
    value += "red: " + command.parameters[0].red.to_i.inspect + ", "
    value += "green: " + command.parameters[0].green.to_i.inspect + ", "
    value += "blue: " + command.parameters[0].blue.to_i.inspect + ", "
    value += "gray: " + command.parameters[0].gray.to_i.inspect + ", " if command.parameters[0].gray != 0.0
    value += "frames: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_screen_flash(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "screen_flash("
    value += "red: " + command.parameters[0].red.to_i.inspect + ", "
    value += "green: " + command.parameters[0].green.to_i.inspect + ", "
    value += "blue: " + command.parameters[0].blue.to_i.inspect + ", "
    value += "alpha: " + command.parameters[0].alpha.to_i.inspect + ", " if command.parameters[0].alpha != 0.0
    value += "frames: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_audio(function, command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + function + "("
    value += audio(command.parameters[0], level + 1)
    value += "),\n"
    return value
  end

  def command_transfer_player(command, level)
    raise "unexpected command parameters" if command.parameters.count != 6
    value = indent(level)
    parameters = []
    if command.parameters[0] == 0
      value += "transfer_player("
      parameters.append "map: " + command.parameters[1].inspect
      parameters.append "x: " + command.parameters[2].inspect
      parameters.append "y: " + command.parameters[3].inspect
    else
      value += "transfer_player_variables("
      parameters.append "map: variable(" + command.parameters[1].inspect + ")"
      parameters.append "x: variable(" + command.parameters[2].inspect + ")"
      parameters.append "y: variable(" + command.parameters[3].inspect + ")"
    end
    parameters.append "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect
    parameters.append "fading: " + (command.parameters[5] == 0 ? 'true' : 'false')
    value += parameters.join(", ")
    value += "),\n"
    return value
  end

  def command_event_location(command, level)
    raise "unexpected command parameters" if command.parameters.count != 5
    value = indent(level)
    if command.parameters[1] == 0
      value += "event_location("
      value += character(command.parameters[0]) + ", "
      value += "x: " + command.parameters[2].inspect + ", "
      value += "y: " + command.parameters[3].inspect + ", "
    elsif command.parameters[1] == 1
      value += "event_location_variables("
      value += character(command.parameters[0]) + ", "
      value += "x: variable(" + command.parameters[2].inspect + "), "
      value += "y: variable(" + command.parameters[3].inspect + "), "
    else
      value += "event_location_swap("
      value += character(command.parameters[0]) + ", "
      value += "target: " + character(command.parameters[0]) + ", "
    end
    value += "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect
    value += "),\n"
    return value
  end

  def command_input_number(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "input_number("
    value += "variable(" + command.parameters[0].inspect + "), "
    value += "digits: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_button_input_processing(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "button_input_processing("
    value += "variable(" + command.parameters[0].inspect + ")"
    value += "),\n"
    return value
  end

  def command_simple(function, count, command, level)
    raise "unexpected command parameters" if command.parameters.count != count
    value = indent(level) + function
    unless count == 0
      value += "("
      (0...count).each do |i|
        value += ", " unless i == 0
        value += command.parameters[i].inspect
      end
      value += ")"
    end
    value += ",\n"
    return value
  end

  def command_switch(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "control_switches("
    value += "switch(" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "), " + command.parameters[2].inspect
    value += "),\n"
    return value
  end

  def command_variable(command, level)
    value = indent(level) + "control_variables("
    value += "variable(" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "), "
    value += RPGFactory::OPERATION[command.parameters[2]].inspect + ", " if command.parameters[2] != 0

    case command.parameters[3]
    when 0
      value += "constant: " + command.parameters[4].inspect
    when 1
      value += "variable: variable(" + command.parameters[4].inspect + ")"
    when 2
      value += "random: " + command.parameters[4].inspect + ".." + command.parameters[5].inspect
    when 3
      value += "item: " + command.parameters[4..].inspect
    when 4
      value += "actor: " + command.parameters[4..].inspect
    when 5
      value += "enemy: " + command.parameters[4..].inspect
    when 6
      value += "character: " + character(command.parameters[4]) + ", "
      value += "property: " + RPGFactory::CHARACTER_PROPERTY[command.parameters[5]].inspect
    when 7
      value += "property: " + RPGFactory::OTHER_PROPERTY[command.parameters[4]].inspect
    end

    value += "),\n"
    return value
  end

  def command_self_switch(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "control_self_switch("
    value += command.parameters[0].inspect + ", " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_change_gold(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "change_gold("
    value += RPGFactory::GOLD_OPERATION[command.parameters[0]].inspect + ", "

    case command.parameters[1]
    when 0
      value += "constant: " + command.parameters[2].inspect
    when 1
      value += "variable: variable(" + command.parameters[2].inspect + ")"
    end

    value += "),\n"
    return value
  end

  def command(command, level)
    command.parameters.each do |parameter|
      raise "missing when for command code " + command.code.to_s if parameter.inspect.start_with?('#')
    end
    value = indent(level) + "command(" + command.code.inspect
    command.parameters.each do |parameter|
      value += ", " + parameter.inspect
    end
    value += "),\n"
    return value
  end

  def graphic(graphic, level)
    value = "graphic(\n"
    value += indent(level + 1) + "tile_id: " + graphic.tile_id.inspect + ",\n" if graphic.tile_id != 0
    value += indent(level + 1) + "character_name: " + graphic.character_name.inspect + ",\n" if graphic.character_name != ""
    value += indent(level + 1) + "character_hue: " + graphic.character_hue.inspect + ",\n" if graphic.character_hue != 0
    value += indent(level + 1) + "direction: " + RPGFactory::DIRECTION[graphic.direction].inspect + ",\n" if graphic.direction != 2
    value += indent(level + 1) + "pattern: " + graphic.pattern.inspect + ",\n" if graphic.pattern != 0
    value += indent(level + 1) + "opacity: " + graphic.opacity.inspect + ",\n" if graphic.opacity != 255
    value += indent(level + 1) + "blend_type: " + graphic.blend_type.inspect + ",\n" if graphic.blend_type != 0
    value += indent(level) + ")"
    return value
  end

  def route(route, level)
    value = "route(\n"
    last = route.list.pop
    raise "unexpected last route command" if Marshal.dump(last) != DEFAULT_MOVE
    route.list.each do |command|
      value += indent(level + 1) + move(command, level + 1) + ",\n"
    end
    value += indent(level + 1) + "repeat: " + route.repeat.inspect + ",\n" if route.repeat != true
    value += indent(level + 1) + "skippable: " + route.skippable.inspect + ",\n" if route.skippable != false
    value += indent(level) + ")"
    return value
  end

  def move(move, level)
    if move.parameters.count == 0
      return "move(code: " + move.code.inspect + ")"
    end

    if move.code == 44
      return "move(code: 44, parameters: [" + audio(move.parameters[0], level) + "])"
    end

    move.parameters.each do |parameter|
      raise "missing if for move code " + move.code.to_s if parameter.inspect.start_with?('#')
    end

    value = "move(\n"
    value += indent(level + 1) + "code: " + move.code.inspect + ",\n"
    value += indent(level + 1) + "parameters: " + move.parameters.inspect + ",\n"
    value += indent(level) + ")"
    return value
  end

  def command_condition(command, level)
    value = indent(level) + "*condition(\n"
    type = RPGFactory::CONDITION_TYPE[command.parameters[0]]

    case type
    when :switch
      raise "unexpected command parameters" if command.parameters.count != 3
      value += indent(level + 1) + "switch: switch(" + command.parameters[1].inspect + "),\n"
      value += indent(level + 1) + "value: " + command.parameters[2].inspect + ",\n"
    when :variable
      raise "unexpected command parameters" if command.parameters.count != 5
      value += indent(level + 1) + "variable: variable(" + command.parameters[1].inspect + "),\n"
      value += indent(level + 1) + "operation: " + RPGFactory::COMPARISON[command.parameters[4]].inspect + ",\n"
      if command.parameters[2] == 0
        value += indent(level + 1) + "constant: " + command.parameters[3].inspect + ",\n"
      else
        value += indent(level + 1) + "other_variable: variable(" + command.parameters[3].inspect + "),\n"
      end
    when :self_switch
      raise "unexpected command parameters" if command.parameters.count != 3
      value += indent(level + 1) + "self_switch: " + command.parameters[1].inspect + ",\n"
      value += indent(level + 1) + "value: " + command.parameters[2].inspect + ",\n"
    when :character
      value += indent(level + 1) + "character: " + character(command.parameters[1]) + ",\n"
      value += indent(level + 1) + "facing: " + RPGFactory::DIRECTION[command.parameters[2]].inspect + ",\n"
    when :gold
      value += indent(level + 1) + "gold: " + command.parameters[1].inspect + ",\n"
      value += indent(level + 1) + "operation: " + RPGFactory::GOLD_COMPARISON[command.parameters[2]].inspect + ",\n"
    when :script
      raise "unexpected command parameters" if command.parameters.count != 2
      value += indent(level + 1) + "script: " + command.parameters[1].inspect + ",\n"
    else
      # TODO print a warning that this condition type isn't supported
      raise "unexpected condition type " + type.to_s
      value += indent(level + 1) + "type: " + type.inspect + ",\n"
      value += indent(level + 1) + "parameters: " + command.parameters[1..].inspect + ",\n"
    end

    return value
  end

  def character(id)
    return "player" if id == -1
    return "this" if id == 0
    return "character(" + id.to_s + ")"
  end

  def command_loop(command, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level) + "*repeat(\n"
    return value
  end

  def command_show_choices(command, level)
    value = indent(level) + "*show_choices(\n"
    value += indent(level + 1) + "choices: " + command.parameters[0].inspect + ",\n"
    value += indent(level + 1) + "cancellation: " + command.parameters[1].inspect + ",\n"
    return value
  end

  def command_when(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level + 1) + "choice" + (command.parameters[0] + 1).to_s + ": [\n"
    return value
  end

  def command_when_cancel(command, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "cancel: [\n"
    return value
  end

  def command_battle(command, level)
    value = indent(level) + "*battle(\n"
    value += indent(level + 1) + "parameters: " + command.parameters.inspect + ",\n"
    return value
  end

  def command_battle_win(command, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "win: [\n"
    return value
  end

  def command_battle_escape(command, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "escape: [\n"
    return value
  end

  def command_battle_lose(command, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "lose: [\n"
    return value
  end

  def command_move_route(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "*move_route(\n"
    value += indent(level + 1) + "character: " + character(command.parameters[0]) + ",\n"
    value += indent(level + 1) + "route: " + route(command.parameters[1], level + 1) + ",\n"
    value += indent(level) + "),\n"
    return value
  end
end
