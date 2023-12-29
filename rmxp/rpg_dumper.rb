class RPGDumper
  def dump_ruby(object, level = 0)
    case object
    when RPG::Map
      return map(object, level)
    when RPG::CommonEvent
      return common_event(object, level)
    when Array
      return array(object, level)
    when Hash
      return hash(object, level)
    when NilClass
      return indent(level) + "nil,\n"
    when RPG::Actor
      return actor(object, level)
    when RPG::Armor
      return armor(object, level)
    when RPG::Class
      return rpg_class(object, level)
    when RPG::Enemy
      return enemy(object, level)
    when RPG::Item
      return item(object, level)
    when RPG::Skill
      return skill(object, level)
    when RPG::State
      return state(object, level)
    when RPG::Troop
      return troop(object, level)
    when RPG::Weapon
      return weapon(object, level)
    when RPG::Tileset
      return tileset(object, level)
    when RPG::MapInfo
      return mapinfo(object, level)
    when RPG::Animation
      return animation(object, level)
    when RPG::System
      return system(object, level)
    else
      puts object.class
    end
  end

  INDENT_SIZE = 2

  def indent(level)
    return ' ' * level * INDENT_SIZE
  end

  DEFAULT_AUDIO = Marshal.dump(RPG::AudioFile.new)
  DEFAULT_BGS = Marshal.dump(RPG::AudioFile.new("", 80))
  DEFAULT_CONDITION = Marshal.dump(RPG::Event::Page::Condition.new)
  DEFAULT_GRAPHIC = Marshal.dump(RPG::Event::Page::Graphic.new)
  DEFAULT_COMMAND = Marshal.dump(RPG::EventCommand.new)
  DEFAULT_ROUTE = Marshal.dump(RPG::MoveRoute.new)
  DEFAULT_MOVE = Marshal.dump(RPG::MoveCommand.new)
  DEFAULT_PAGE = Marshal.dump(RPG::Event::Page.new)

  def array(array, level)
    value = indent(level) + "[\n"
    array.each do |object|
      value += dump_ruby(object, level + 1)
    end
    value += indent(level) + "]\n"
    return value
  end

  def hash(array, level)
    value = indent(level) + "{\n"
    array.each do |key, object|
      value += indent(level + 1) + key.inspect + " => " + dump_ruby(object, level + 1)
    end
    value += indent(level) + "}\n"
    return value
  end

  def map(map, level)
    value = indent(level) + "map(\n"
    value += indent(level + 1) + "tileset_id: " + map.tileset_id.inspect + ",\n" if map.tileset_id != 1
    value += indent(level + 1) + "autoplay_bgm: " + map.autoplay_bgm.inspect + ",\n" if map.autoplay_bgm != false
    value += indent(level + 1) + "bgm: " + audio(map.bgm) + ",\n" if Marshal.dump(map.bgm) != DEFAULT_AUDIO
    value += indent(level + 1) + "autoplay_bgs: " + map.autoplay_bgs.inspect + ",\n" if map.autoplay_bgs != false
    value += indent(level + 1) + "bgs: " + audio(map.bgs) + ",\n" if Marshal.dump(map.bgs) != DEFAULT_BGS
    raise "non-empty map encounter_list" if map.encounter_list != []
    value += indent(level + 1) + "encounter_step: " + map.encounter_step.inspect + ",\n" if map.encounter_step != 30
    value += indent(level + 1) + "events: [\n\n"
    map.events.each do |key, event|
      value += event(event, level + 2) + ",\n\n"
    end
    value += indent(level + 1) + "],\n"
    value += indent(level + 1) + "data: " + table(map.data, level + 1, pretty: true) + ",\n"
    value += indent(level) + ")\n"
    return value
  end

  def common_event(event, level)
    value = indent(level) + "common_event(\n"
    value += indent(level + 1) + "id: " + event.id.inspect + ",\n" if event.id != 0
    value += indent(level + 1) + "name: " + event.name.inspect + ",\n" if event.name != ""
    value += indent(level + 1) + "trigger: " + RPGFactory::COMMON_EVENT_TRIGGER[event.trigger].inspect + ",\n" if event.trigger != 0
    value += indent(level + 1) + "switch: s(" + event.switch_id.inspect + "),\n" if event.trigger != 0

    commands = event.list.clone
    last = commands.pop
    raise "unexpected last event command" if Marshal.dump(last) != DEFAULT_COMMAND
    if event.list.count > 1
      value += command_array(commands, level + 1)
    end
    value += indent(level) + "),\n"
    return value
  end

  def audio(audio)
    value = "audio("
    parameters = []
    parameters.append "name: " + audio.name.inspect if audio.name != ""
    parameters.append "volume: " + audio.volume.inspect if audio.volume != 100
    parameters.append "pitch: " + audio.pitch.inspect if audio.pitch != 100
    value += parameters.join(", ")
    value += ")"
    return value
  end

  def table(table, level, pretty: false, inline: false)
    value = "table("
    value += "\n" unless inline

    value += indent(level + 1) unless inline
    value += "x: " + table.xsize.inspect + ","
    value += inline ? " " : "\n"

    if table.ysize > 1
      value += indent(level + 1) unless inline
      value += "y: " + table.ysize.inspect + ","
      value += inline ? " " : "\n"
    end

    if table.zsize > 1
      value += indent(level + 1) unless inline
      value += "z: " + table.zsize.inspect + ","
      value += inline ? " " : "\n"
    end

    if pretty
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
      value = value.rstrip + "\n"
      value += indent(level + 1) + "],\n"
    else
      value += indent(level + 1) unless inline
      value += "data: " + table.data.inspect
      value += ",\n" unless inline
    end

    value += indent(level) unless inline
    value += ")"
    return value
  end

  def event(event, level)
    value = indent(level) + "event(\n"
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
      value += indent(level + 1) + "switch1: s(" + page.condition.switch1_id.inspect + "),\n" if page.condition.switch1_valid
      value += indent(level + 1) + "switch2: s(" + page.condition.switch2_id.inspect + "),\n" if page.condition.switch2_valid
      value += indent(level + 1) + "variable: v(" + page.condition.variable_id.inspect + "),\n" if page.condition.variable_valid
      value += indent(level + 1) + "at_least: " + page.condition.variable_value.inspect + ",\n" if page.condition.variable_value != 0
      value += indent(level + 1) + "self_switch: " + page.condition.self_switch_ch.inspect + ",\n" if page.condition.self_switch_valid
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
      value += command_array(commands, level + 1)
    end

    value += indent(level) + ")"
    return value
  end

  def command_array(commands, level)
    value = indent(level) + "commands: "
    index = single_condition_end(commands, 0)
    if index != nil
      # condition nesting reduction
      value += command_list(commands, level, true)
    else
      value += "[\n"
      value += command_list(commands, level + 1)
      value += indent(level) + "],\n"
    end
    return value
  end

  def command_list(commands, level, nesting_reduction = false)
    value = ""
    i = 0
    while i < commands.count
      command = commands[i]
      case command.code

      # Flow control commands
      when -1 # reduced nesting end
        # condition nesting reduction
        level -= 1
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
        condition = command_condition(command, level)
        # nesting reduction when a branch only contains another condition
        # this is achieved by removing the indent and star here
        # and replacing the ending 0 command with -1
        if nesting_reduction
          nesting_reduction = false
          condition = condition[(INDENT_SIZE * level + 1)..]
        end
        value += condition
        if commands[i + 1].code == 0
          i += 1
        else
          value += indent(level + 1) + "then: "
          index = single_condition_end(commands, i + 1)
          if index != nil
            # condition nesting reduction
            commands[index].code = -1
            level += 1
            nesting_reduction = true
          else
            value += "[\n"
            level += 2
          end
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
        if commands[i + 1].code == 0
          i += 1
        else
          value += indent(level + 1) + "else: "
          index = single_condition_end(commands, i + 1)
          if index != nil
            # condition nesting reduction
            commands[index].code = -1
            level += 1
            nesting_reduction = true
          else
            value += "[\n"
            level += 2
          end
        end
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
      when 108 # comment
        parts = collect(commands, i + 1, 408)
        i += parts.count
        parts.unshift(command)
        value += command_comment(parts, level)
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
      when 134 # change save access
        value += command_access("change_save_access", command, level)
      when 135 # change menu access
        value += command_access("change_menu_access", command, level)
      when 136 # change encounter
        value += command_access("change_encounter", command, level)
      when 201 # transfer player
        value += command_transfer_player(command, level)
      when 202 # set event location
        value += command_event_location(command, level)
      when 203 # scroll map
        value += command_scroll_map(command, level)
      when 204 # change map settings
        value += command_change_map_settings(command, level)
      when 205 # change for color tone
        value += command_change_fog_tone(command, level)
      when 206 # change for opacity
        value += command_change_fog_opacity(command, level)
      when 207 # show animation
        value += command_show_animation(command, level)
      when 208 # change transparent flag
        value += command_change_transparent_flag(command, level)
      when 210 # wait for move's completion
        value += command_simple("wait_completion", 0, command, level)
      when 221 # prepare for transition
        value += command_simple("prepare_transition", 0, command, level)
      when 222 # execute transition
        value += command_simple("execute_transition", 1, command, level)
      when 223 # change screen color tone
        value += command_change_tone(command, level)
      when 224 # screen flash
        value += command_screen_flash(command, level)
      when 225 # screen shake
        value += command_screen_shake(command, level)
      when 231 # show picture
        value += command_show_picture(command, level)
      when 232 # move picture
        value += command_move_picture(command, level)
      when 233 # rotate picture
        value += command_rotate_picture(command, level)
      when 234 # change picture tone
        value += command_change_picture_tone(command, level)
      when 235 # erase picture
        value += command_erase_picture(command, level)
      when 236 # set weather effects
        value += command_weather_effect(command, level)
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
      when 251 # stop se
        value += command_simple("stop_se", 0, command, level)
      when 242 # fade out bgm
        value += command_fade_out_bgm(command, level)
      when 246 # fade out bgs
        value += command_fade_out_bgs(command, level)
      when 314 # recover all
        value += command_simple("recover_all", 1, command, level)
      when 351 # call menu screen
        value += command_simple("call_menu_screen", 0, command, level)
      when 352 # call save screen
        value += command_simple("call_save_screen", 0, command, level)
      when 353 # game over
        value += command_simple("game_over", 0, command, level)
      when 354 # title screen
        value += command_simple("title_screen", 0, command, level)
      when 247 # memorize bgm bgs
        value += command_simple("memorize_bgm_bgs", 0, command, level)
      when 248 # restore bgm bgs
        value += command_simple("restore_bgm_bgs", 0, command, level)

      # Unknown command
      else
        value += command(command, level)
      end
      i += 1
    end
    return value
  end

  def single_condition_end(commands, index)
    return nil unless commands[index].code == 111
    indent = commands[index].indent
    index += 1
    length = commands.length
    while index < length && commands[index].indent >= indent
      return nil if commands[index].indent == indent && ![0, 411, 412].include?(commands[index].code)
      index += 1
    end
    return index - 1
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

  def command_comment(commands, level)
    if commands.count == 1
      value = indent(level) + "comment("
      raise "unexpected command parameters" if commands[0].parameters.count != 1
      value += commands[0].parameters[0].inspect + "),\n"
      return value
    end

    value = indent(level) + "*comment(\n"
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
    value += indent(level + 1) + "<<~'CODE'\n"
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

  def command_change_fog_opacity(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "change_fog_opacity("
    value += "opacity: " + command.parameters[0].inspect + ", "
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

  def command_screen_shake(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "screen_shake("
    value += "power: " + command.parameters[0].inspect + ", "
    value += "speed: " + command.parameters[1].inspect + ", "
    value += "frames: " + command.parameters[2].inspect
    value += "),\n"
    return value
  end

  def command_show_animation(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "show_animation("
    value += character(command.parameters[0]) + ", "
    value += "anim(" + command.parameters[1].inspect + ")"
    value += "),\n"
    return value
  end

  def command_audio(function, command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + function + "("
    value += audio(command.parameters[0])
    value += "),\n"
    return value
  end

  def command_fade_out_bgm(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "fade_out_bgm("
    value += "seconds: " + command.parameters[0].inspect
    value += "),\n"
    return value
  end

  def command_fade_out_bgs(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "fade_out_bgs("
    value += "seconds: " + command.parameters[0].inspect
    value += "),\n"
    return value
  end

  def command_transfer_player(command, level)
    raise "unexpected command parameters" if command.parameters.count != 6
    value = indent(level)
    if command.parameters[0] == 0
      value += "transfer_player("
      value += "map: " + command.parameters[1].inspect + ", "
      value += "x: " + command.parameters[2].inspect + ", "
      value += "y: " + command.parameters[3].inspect + ", "
    else
      value += "transfer_player_variables("
      value += "map: v(" + command.parameters[1].inspect + "), "
      value += "x: v(" + command.parameters[2].inspect + "), "
      value += "y: v(" + command.parameters[3].inspect + "), "
    end
    value += "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect + ", "
    value += "fading: " + (command.parameters[5] == 0 ? 'true' : 'false')
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
      value += "x: v(" + command.parameters[2].inspect + "), "
      value += "y: v(" + command.parameters[3].inspect + "), "
    else
      value += "event_location_swap("
      value += character(command.parameters[0]) + ", "
      value += "target: " + character(command.parameters[2]) + ", "
    end
    value += "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect
    value += "),\n"
    return value
  end

  def command_input_number(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "input_number("
    value += "v(" + command.parameters[0].inspect + "), "
    value += "digits: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_button_input_processing(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "button_input_processing("
    value += "v(" + command.parameters[0].inspect + ")"
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
    value += "s(" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "), " + (command.parameters[2] == 1 ? "true" : "false")
    value += "),\n"
    return value
  end

  def command_variable(command, level)
    value = indent(level) + "control_variables("
    value += "v(" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "), "
    value += RPGFactory::OPERATION[command.parameters[2]].inspect + ", " if command.parameters[2] != 0

    case command.parameters[3]
    when 0
      value += "constant: " + command.parameters[4].inspect
    when 1
      value += "variable: v(" + command.parameters[4].inspect + ")"
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
      value += "variable: v(" + command.parameters[2].inspect + ")"
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
    value += indent(level + 1) + "name: " + graphic.character_name.inspect + ",\n" if graphic.character_name != ""
    value += indent(level + 1) + "hue: " + graphic.character_hue.inspect + ",\n" if graphic.character_hue != 0
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
    case move.code
    when 1 then return "move_down"
    when 2 then return "move_left"
    when 3 then return "move_right"
    when 4 then return "move_up"
    when 5 then return "move_lower_left"
    when 6 then return "move_lower_right"
    when 7 then return "move_upper_left"
    when 8 then return "move_upper_right"
    when 9 then return "move_random"
    when 10 then return "move_toward_player"
    when 11 then return "move_away_from_player"
    when 12 then return "move_forward"
    when 13 then return "move_backward"
    when 14 then return "jump(x: " + move.parameters[0].inspect + ", y: " + move.parameters[1].inspect + ")"
    when 15 then return "route_wait(" + move.parameters[0].inspect + ")"
    when 16 then return "turn_down"
    when 17 then return "turn_left"
    when 18 then return "turn_right"
    when 19 then return "turn_up"
    when 20 then return "turn_right_90"
    when 21 then return "turn_left_90"
    when 22 then return "turn_180"
    when 23 then return "turn_right_or_left_90"
    when 24 then return "turn_random"
    when 25 then return "turn_toward_player"
    when 26 then return "turn_away_from_player"
    when 27 then return "switch_on(s(" + move.parameters[0].inspect + "))"
    when 28 then return "switch_off(s(" + move.parameters[0].inspect + "))"
    when 29 then return "change_speed(" + move.parameters[0].inspect + ")"
    when 30 then return "change_frequency(" + move.parameters[0].inspect + ")"
    when 31 then return "walk_anime_on"
    when 32 then return "walk_anime_off"
    when 33 then return "step_anime_on"
    when 34 then return "step_anime_off"
    when 35 then return "direction_fix_on"
    when 36 then return "direction_fix_off"
    when 37 then return "through_on"
    when 38 then return "through_off"
    when 39 then return "always_on_top_on"
    when 40 then return "always_on_top_off"
    when 41
      parameters = []
      parameters.append "name: " + move.parameters[0].inspect if move.parameters[0] != ""
      parameters.append "hue: " + move.parameters[1].inspect if move.parameters[1] != 0
      parameters.append "direction: " + RPGFactory::DIRECTION[move.parameters[2]].inspect if move.parameters[2] != 2
      parameters.append "pattern: " + move.parameters[3].inspect if move.parameters[3] != 0
      return "remove_graphic" if parameters == []
      return "change_graphic(" + parameters.join(", ") + ")"
    when 42 then return "change_opacity(" + move.parameters[0].inspect + ")"
    when 43 then return "change_blending(" + RPGFactory::BLENDING[move.parameters[0]].inspect + ")"
    when 44 then return "route_play_se(" + audio(move.parameters[0]) + ")"
    when 45 then return "route_script(" + move.parameters[0].inspect + ")"
    else
      value = "move(" + move.code.inspect
      move.parameters.each do |parameter|
        value += ", " + parameter.inspect
      end
      value += ")"
      return value
    end
  end

  def command_condition(command, level)
    value = indent(level) + "*condition(\n"
    type = RPGFactory::CONDITION_TYPE[command.parameters[0]]

    case type
    when :switch
      raise "unexpected command parameters" if command.parameters.count != 3
      value += indent(level + 1) + "switch: s(" + command.parameters[1].inspect + "),\n"
      value += indent(level + 1) + "value: " + command.parameters[2].inspect + ",\n"
    when :variable
      raise "unexpected command parameters" if command.parameters.count != 5
      value += indent(level + 1) + "variable: v(" + command.parameters[1].inspect + "),\n"
      value += indent(level + 1) + "operation: " + RPGFactory::COMPARISON[command.parameters[4]].inspect + ",\n"
      if command.parameters[2] == 0
        value += indent(level + 1) + "constant: " + command.parameters[3].inspect + ",\n"
      else
        value += indent(level + 1) + "other_variable: v(" + command.parameters[3].inspect + "),\n"
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
      # raise "unexpected condition type " + type.to_s
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
    value += indent(level + 1) + character(command.parameters[0]) + ",\n"
    route = command.parameters[1]
    last = route.list.pop
    raise "unexpected last route command" if Marshal.dump(last) != DEFAULT_MOVE
    route.list.each do |move|
      value += indent(level + 1) + move(move, level + 1) + ",\n"
    end
    value += indent(level + 1) + "repeat: " + route.repeat.inspect + ",\n" if route.repeat != false
    value += indent(level + 1) + "skippable: " + route.skippable.inspect + ",\n" if route.skippable != false
    value += indent(level) + "),\n"
    return value
  end

  def command_change_map_settings(command, level)
    value = indent(level)
    if command.parameters[0] == 0
      raise "unexpected command parameters" if command.parameters.count != 3
      value += "change_panorama("
      value += "graphic: " + command.parameters[1].inspect + ", "
      value += "hue: " + command.parameters[2].inspect
      value += "),\n"
    elsif command.parameters[0] == 1
      raise "unexpected command parameters" if command.parameters.count != 8
      value += "change_fog(\n"
      value += indent(level + 1) + "graphic: " + command.parameters[1].inspect + ",\n"
      value += indent(level + 1) + "hue: " + command.parameters[2].inspect + ",\n"
      value += indent(level + 1) + "opacity: " + command.parameters[3].inspect + ",\n"
      value += indent(level + 1) + "blending: " + RPGFactory::BLENDING[command.parameters[4]].inspect + ",\n"
      value += indent(level + 1) + "zoom: " + command.parameters[5].inspect + ",\n"
      value += indent(level + 1) + "sx: " + command.parameters[6].inspect + ",\n" unless command.parameters[6] == 0
      value += indent(level + 1) + "sy: " + command.parameters[7].inspect + ",\n" unless command.parameters[7] == 0
      value += indent(level) + "),\n"
    else
      raise "unexpected command parameters" if command.parameters.count != 2
      value += "change_battleback(graphic:" + command.parameters[1].inspect + "),\n"
    end
    return value
  end

  def command_show_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 10
    value = indent(level)
    if command.parameters[3] == 0
      value += "show_picture(\n"
    else
      value += "show_picture_variables(\n"
    end
    value += indent(level + 1) + "number: " + command.parameters[0].inspect + ",\n"
    value += indent(level + 1) + "graphic: " + command.parameters[1].inspect + ",\n"
    value += indent(level + 1) + "origin: " + RPGFactory::ORIGIN[command.parameters[2]].inspect + ",\n"
    if command.parameters[3] == 0
      value += indent(level + 1) + "x: " + command.parameters[4].inspect + ",\n" if command.parameters[4] != 0
      value += indent(level + 1) + "y: " + command.parameters[5].inspect + ",\n" if command.parameters[5] != 0
    else
      value += indent(level + 1) + "x: v(" + command.parameters[4].inspect + "),\n"
      value += indent(level + 1) + "y: v(" + command.parameters[5].inspect + "),\n"
    end
    value += indent(level + 1) + "zoom_x: " + command.parameters[6].inspect + ",\n" if command.parameters[6] != 100
    value += indent(level + 1) + "zoom_y: " + command.parameters[7].inspect + ",\n" if command.parameters[7] != 100
    value += indent(level + 1) + "opacity: " + command.parameters[8].inspect + ",\n" if command.parameters[8] != 255
    value += indent(level + 1) + "blending: " + RPGFactory::BLENDING[command.parameters[9]].inspect + ",\n"
    value += indent(level) + "),\n"
    return value
  end

  def command_move_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 10
    value = indent(level)
    if command.parameters[3] == 0
      value += "move_picture(\n"
    else
      value += "move_picture_variables(\n"
    end
    value += indent(level + 1) + "number: " + command.parameters[0].inspect + ",\n"
    value += indent(level + 1) + "frames: " + command.parameters[1].inspect + ",\n"
    value += indent(level + 1) + "origin: " + RPGFactory::ORIGIN[command.parameters[2]].inspect + ",\n"
    if command.parameters[3] == 0
      value += indent(level + 1) + "x: " + command.parameters[4].inspect + ",\n" if command.parameters[4] != 0
      value += indent(level + 1) + "y: " + command.parameters[5].inspect + ",\n" if command.parameters[5] != 0
    else
      value += indent(level + 1) + "x: v(" + command.parameters[4].inspect + "),\n"
      value += indent(level + 1) + "y: v(" + command.parameters[5].inspect + "),\n"
    end
    value += indent(level + 1) + "zoom_x: " + command.parameters[6].inspect + ",\n" if command.parameters[6] != 100
    value += indent(level + 1) + "zoom_y: " + command.parameters[7].inspect + ",\n" if command.parameters[7] != 100
    value += indent(level + 1) + "opacity: " + command.parameters[8].inspect + ",\n" if command.parameters[8] != 255
    value += indent(level + 1) + "blending: " + RPGFactory::BLENDING[command.parameters[9]].inspect + ",\n"
    value += indent(level) + "),\n"
    return value
  end

  def command_rotate_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "rotate_picture("
    value += "number: " + command.parameters[0].inspect + ", "
    value += "speed: " + command.parameters[1].inspect
    value += "),\n"
    return value
  end

  def command_erase_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "erase_picture("
    value += "number: " + command.parameters[0].inspect
    value += "),\n"
    return value
  end

  def command_weather_effect(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "weather_effect("
    value += "weather: " + RPGFactory::WEATHER[command.parameters[0]].inspect + ", "
    value += "power: " + command.parameters[1].inspect + ", "
    value += "frames: " + command.parameters[2].inspect
    value += "),\n"
    return value
  end

  def command_change_transparent_flag(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "change_transparent_flag("
    value += RPGFactory::TRANSPARENT_FLAG[command.parameters[0]].inspect
    value += "),\n"
    return value
  end

  def command_access(function, command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + function + "("
    value += RPGFactory::ACCESS[command.parameters[0]].inspect
    value += "),\n"
    return value
  end

  def actor(object, level)
    return indent(level) + "actor(" + object.id.inspect + ", " + object.name.inspect + "),\n"
  end

  def armor(object, level)
    return indent(level) + "armor(" + object.id.inspect + "),\n"
  end

  def rpg_class(object, level)
    return indent(level) + "rpg_class(" + object.id.inspect + "),\n"
  end

  def enemy(object, level)
    return indent(level) + "enemy(" + object.id.inspect + "),\n"
  end

  def item(object, level)
    return indent(level) + "item(" + object.id.inspect + "),\n"
  end

  def skill(object, level)
    return indent(level) + "skill(" + object.id.inspect + "),\n"
  end

  def state(object, level)
    return indent(level) + "state(" + object.id.inspect + "),\n"
  end

  def troop(object, level)
    return indent(level) + "troop(" + object.id.inspect + "),\n"
  end

  def weapon(object, level)
    return indent(level) + "weapon(" + object.id.inspect + "),\n"
  end

  def tileset(tileset, level)
    value = indent(level) + "tileset(\n"
    value += indent(level + 1) + "id: " + tileset.id.inspect + ",\n"
    value += indent(level + 1) + "name: " + tileset.name.inspect + ",\n"
    value += indent(level + 1) + "tileset_name: " + tileset.tileset_name.inspect + ",\n"
    value += indent(level + 1) + "autotile_names: " + tileset.autotile_names.inspect + ",\n"
    value += indent(level + 1) + "panorama_name: " + tileset.panorama_name.inspect + ",\n" if tileset.panorama_name != ""
    value += indent(level + 1) + "panorama_hue: " + tileset.panorama_hue.inspect + ",\n" if tileset.panorama_hue != 0
    value += indent(level + 1) + "fog_name: " + tileset.fog_name.inspect + ",\n" if tileset.fog_name != ""
    value += indent(level + 1) + "fog_hue: " + tileset.fog_hue.inspect + ",\n" if tileset.fog_hue != 0
    value += indent(level + 1) + "fog_opacity: " + tileset.fog_opacity.inspect + ",\n" if tileset.fog_opacity != 64
    value += indent(level + 1) + "fog_blending: " + RPGFactory::BLENDING[tileset.fog_blend_type].inspect + ",\n" if tileset.fog_blend_type != 0
    value += indent(level + 1) + "fog_zoom: " + tileset.fog_zoom.inspect + ",\n" if tileset.fog_zoom != 200
    value += indent(level + 1) + "fog_sx: " + tileset.fog_sx.inspect + ",\n" if tileset.fog_sx != 0
    value += indent(level + 1) + "fog_sy: " + tileset.fog_sy.inspect + ",\n" if tileset.fog_sy != 0
    value += indent(level + 1) + "battleback_name: " + tileset.battleback_name.inspect + ",\n" if tileset.battleback_name != ""
    value += indent(level + 1) + "passages: " + table(tileset.passages, level + 1) + ",\n"
    value += indent(level + 1) + "priorities: " + table(tileset.priorities, level + 1) + ",\n"
    value += indent(level + 1) + "terrain_tags: " + table(tileset.terrain_tags, level + 1) + ",\n"
    value += indent(level) + "),\n"
    return value
  end

  def mapinfo(mapinfo, level)
    value = "mapinfo(\n"
    value += indent(level + 1) + "name: " + mapinfo.name.inspect + ",\n" if mapinfo.name != ""
    value += indent(level + 1) + "parent_id: " + mapinfo.parent_id.inspect + ",\n" if mapinfo.parent_id != 0
    value += indent(level + 1) + "order: " + mapinfo.order.inspect + ",\n" if mapinfo.order != 0
    value += indent(level + 1) + "expanded: " + mapinfo.expanded.inspect + ",\n" if mapinfo.expanded != false
    value += indent(level + 1) + "scroll_x: " + mapinfo.scroll_x.inspect + ",\n" if mapinfo.scroll_x != 0
    value += indent(level + 1) + "scroll_y: " + mapinfo.scroll_y.inspect + ",\n" if mapinfo.scroll_y != 0
    value += indent(level) + "),\n"
    return value
  end

  def animation(animation, level)
    value = "\n" + indent(level) + "animation(\n"
    value += indent(level + 1) + "id: " + animation.id.inspect + ",\n"
    value += indent(level + 1) + "name: " + animation.name.inspect + ",\n" if animation.name != ""
    value += indent(level + 1) + "animation: " + animation.animation_name.inspect + ",\n" if animation.animation_name != ""
    value += indent(level + 1) + "hue: " + animation.animation_hue.inspect + ",\n" if animation.animation_hue != 0
    value += indent(level + 1) + "position: " + animation.position.inspect + ",\n" if animation.position != 1
    value += indent(level + 1) + "frame_max: " + animation.frame_max.inspect + ",\n" if animation.frame_max != 1

    value += indent(level + 1) + "frames: [\n"
    animation.frames.each do |frame|
      value += indent(level + 2) + frame(frame, level + 2) + "\n"
    end
    value += indent(level + 1) + "],\n"

    if animation.timings != []
      value += indent(level + 1) + "timings: [\n"
      animation.timings.each do |timing|
        value += indent(level + 2) + timing(timing, level + 2) + "\n"
      end
      value += indent(level + 1) + "],\n"
    end

    value += indent(level) + "),\n"
    return value
  end

  def frame(frame, level)
    value = "frame("
    value += "max: " + frame.cell_max.inspect + ", "
    value += "data: " + table(frame.cell_data, level + 1, inline: true)
    value += "),"
    return value
  end

  def timing(timing, level)
    value = "timing("
    value += "frame: " + timing.frame.inspect + ", "
    value += "se: " + audio(timing.se) + ", " if Marshal.dump(timing.se) != DEFAULT_BGS
    value += "condition: " + timing.condition.inspect + ", " if timing.condition != 0
    value += "scope: " + timing.flash_scope.inspect + ", " if timing.flash_scope != 0
    value += "duration: " + timing.flash_duration.inspect + ", "
    value += "red: " + timing.flash_color.red.to_i.inspect + ", "
    value += "green: " + timing.flash_color.green.to_i.inspect + ", "
    value += "blue: " + timing.flash_color.blue.to_i.inspect + ", "
    value += "alpha: " + timing.flash_color.alpha.to_i.inspect
    value += "),"
    return value
  end

  def system(system, level)
    value = indent(level) + "system(\n"

    value += indent(level + 1) + "windowskin_name: " + system.windowskin_name.inspect + ",\n" if system.windowskin_name != ""
    value += indent(level + 1) + "title_name: " + system.title_name.inspect + ",\n" if system.title_name != ""
    value += indent(level + 1) + "gameover_name: " + system.gameover_name.inspect + ",\n" if system.gameover_name != ""
    value += indent(level + 1) + "battle_transition: " + system.battle_transition.inspect + ",\n" if system.battle_transition != ""
    value += indent(level + 1) + "battleback_name: " + system.battleback_name.inspect + ",\n" if system.battleback_name != ""
    value += indent(level + 1) + "battler_name: " + system.battler_name.inspect + ",\n" if system.battler_name != ""
    value += indent(level + 1) + "battler_hue: " + system.battler_hue.inspect + ",\n" if system.battler_hue != 0

    value += indent(level + 1) + "title_bgm: " + audio(system.title_bgm) + ",\n" if Marshal.dump(system.title_bgm) != DEFAULT_AUDIO
    value += indent(level + 1) + "battle_bgm: " + audio(system.battle_bgm) + ",\n" if Marshal.dump(system.battle_bgm) != DEFAULT_AUDIO
    value += indent(level + 1) + "battle_end_me: " + audio(system.battle_end_me) + ",\n" if Marshal.dump(system.battle_end_me) != DEFAULT_AUDIO
    value += indent(level + 1) + "gameover_me: " + audio(system.gameover_me) + ",\n" if Marshal.dump(system.gameover_me) != DEFAULT_AUDIO
    value += indent(level + 1) + "cursor_se: " + audio(system.cursor_se) + ",\n" if Marshal.dump(system.cursor_se) != DEFAULT_BGS
    value += indent(level + 1) + "decision_se: " + audio(system.decision_se) + ",\n" if Marshal.dump(system.decision_se) != DEFAULT_BGS
    value += indent(level + 1) + "cancel_se: " + audio(system.cancel_se) + ",\n" if Marshal.dump(system.cancel_se) != DEFAULT_BGS
    value += indent(level + 1) + "buzzer_se: " + audio(system.buzzer_se) + ",\n" if Marshal.dump(system.buzzer_se) != DEFAULT_BGS
    value += indent(level + 1) + "equip_se: " + audio(system.equip_se) + ",\n" if Marshal.dump(system.equip_se) != DEFAULT_BGS
    value += indent(level + 1) + "shop_se: " + audio(system.shop_se) + ",\n" if Marshal.dump(system.shop_se) != DEFAULT_BGS
    value += indent(level + 1) + "save_se: " + audio(system.save_se) + ",\n" if Marshal.dump(system.save_se) != DEFAULT_BGS
    value += indent(level + 1) + "load_se: " + audio(system.load_se) + ",\n" if Marshal.dump(system.load_se) != DEFAULT_BGS
    value += indent(level + 1) + "battle_start_se: " + audio(system.battle_start_se) + ",\n" if Marshal.dump(system.battle_start_se) != DEFAULT_BGS
    value += indent(level + 1) + "escape_se: " + audio(system.escape_se) + ",\n" if Marshal.dump(system.escape_se) != DEFAULT_BGS
    value += indent(level + 1) + "actor_collapse_se: " + audio(system.actor_collapse_se) + ",\n" if Marshal.dump(system.actor_collapse_se) != DEFAULT_BGS
    value += indent(level + 1) + "enemy_collapse_se: " + audio(system.enemy_collapse_se) + ",\n" if Marshal.dump(system.enemy_collapse_se) != DEFAULT_BGS

    value += indent(level + 1) + "magic_number: " + system.magic_number.inspect + ",\n" if system.magic_number != 0
    value += indent(level + 1) + "party_members: " + system.party_members.inspect + ",\n" if system.party_members != [1]
    value += indent(level + 1) + "test_troop_id: " + system.test_troop_id.inspect + ",\n" if system.test_troop_id != 1
    value += indent(level + 1) + "edit_map_id: " + system.edit_map_id.inspect + ",\n" if system.edit_map_id != 1
    value += indent(level + 1) + "start_map_id: " + system.start_map_id.inspect + ",\n" if system.start_map_id != 1
    value += indent(level + 1) + "start_x: " + system.start_x.inspect + ",\n" if system.start_x != 0
    value += indent(level + 1) + "start_y: " + system.start_y.inspect + ",\n" if system.start_y != 0
    value += indent(level + 1) + "elements: " + system.elements.inspect + ",\n" if system.elements != ["", ""]

    # Not supported
    # value += indent(level + 1) + "words: " + system.words.inspect + ",\n"
    # value += indent(level + 1) + "test_battlers: " + system.test_battlers.inspect + ",\n"

    value += indent(level + 1) + "switches: [\n"
    system.switches.each_with_index do |switch, index|
      value += indent(level + 2) + switch.inspect + ", # s(" + index.to_s + ")\n"
    end
    value += indent(level + 1) + "],\n"

    value += indent(level + 1) + "variables: [\n"
    system.variables.each_with_index do |variable, index|
      value += indent(level + 2) + variable.inspect + ", # v(" + index.to_s + ")\n"
    end
    value += indent(level + 1) + "],\n"

    value += indent(level) + ")\n"
    return value
  end
end
