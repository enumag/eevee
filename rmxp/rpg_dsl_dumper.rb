class RPGDSLDumper < RPGDumper
  def command_array(commands, level)
    value = indent(level) + "commands: dsl {\n"
    value += command_list(commands, level + 1)
    value += indent(level) + "},\n"
    return value
  end

  # nesting reduction isn't relevant for dsl
  def command_list(commands, level, nesting_reduction = false)

    commands.pop if !commands.empty? && commands[-1].code == 0

    choices_stack = []

    start_level = level
    value = ""
    i = 0
    while i < commands.count
      command = commands[i]
      case command.code

      # Flow control commands
      when 0 # block end
        level -= 1
        value += indent(level) + "}\n"
        # Band-aid for a rare case of two code 0 commands.
        parts = collect(commands, i + 1, 0)
        i += parts.count
      when 404 # show choices end
        level -= 1
        value += indent(level) + "}\n"
        choices_stack.pop
      when 412, 413, 604 # branch end, loop end, battle end
        # no-op
      when 102 # show choices
        choices_stack.push([command.parameters[0], command.parameters[1], level])
        value += command_show_choices(command, level)
        level += 1
      when 402 # show choices - when
        empty = commands[i + 1].code == 0
        current_choices, current_cancellation, _ = choices_stack[-1]
        value += command_when(command, empty, current_cancellation, current_choices, level)
        level += 1 unless empty
        i += 1 if empty
      when 403 # show choices - when cancel
        empty = commands[i + 1].code == 0
        value += command_when_cancel(command, empty, level)
        level += 1 unless empty
        i += 1 if empty
      when 111 # if
        empty = commands[i + 1].code == 0
        value += command_condition(command, empty, level)
        level += 1 unless empty
        i += 1 if empty
      when 112 # loop
        empty = commands[i + 1].code == 0
        value += command_loop(command, empty, level)
        level += 1 unless empty
        i += 1 if empty
      when 411 # else
        empty = commands[i + 1].code == 0
        value.chomp! # hehe eto blep
        value += ".else {"
        value += "}" if empty
        value += "\n"
        level += 1 unless empty
        i += 1 if empty
      # Control flow battle commands
      when 301
        empty = commands[i + 1].code == 0
        value += command_battle(command, level)
        level += 1 unless empty
        i += 1 if empty
      when 601
        empty = commands[i + 1].code == 0
        value += command_battle_win(command, empty, level)
        level += 1 unless empty
        i += 1 if empty
      when 602
        empty = commands[i + 1].code == 0
        value += command_battle_escape(command, empty, level)
        level += 1 unless empty
        i += 1 if empty
      when 603
        empty = commands[i + 1].code == 0
        value += command_battle_lose(command, empty, level)
        level += 1 unless empty
        i += 1 if empty

      # Command groups
      when 101 # text
        parts = collect(commands, i + 1, 401)
        i += parts.count
        parts.unshift(command)
        # Special case for simple choices
        if parts.size == 1 && commands.size > i + 1 && commands[i + 1].code == 102
          choices_stack.push([commands[i + 1].parameters[0], commands[i + 1].parameters[1], level])
          value += command_show_choices(commands[i + 1], level, text: parts[0].parameters[0])
          level += 1
          i += 1
        else
          value += command_text(parts, level)
        end
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
        next_wait = commands.size > i + 1 && commands[i + 1].code == 210
        value += command_move_route(command, next_wait, level)
        i += 1 if next_wait

      # Other commands
      when 103 # input number
        value += command_input_number(command, level)
      when 104 # change text options
        value += command_change_text_options(command, level)
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
      when 124 # control timer
        value += command_timer(command, level)
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
        value += command_simple("wait_for_move_completion", 0, command, level)
      when 221 # prepare for transition
        value += command_simple("prepare_for_transition", 0, command, level)
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
    if level > start_level
      if level - start_level > 1
        print "oh fuck this isn't good"
      end
      (level - start_level).times do
        level -= 1
        value += indent(level) + "}\n"
      end
    end
    return value
  end

  def character(id)
    return "player" if id == -1
    return "this" if id == 0
    return "events[" + id.to_s + "]"
  end

  def command_indented_simple(command, parts, level)
    command = command + " " unless parts.empty?
    spacer = ",\n" + indent(level) + " " * command.length
    value = indent(level) + command
    value += parts.join(spacer)
    value += "\n"
    return value
  end

  def command_parameterized_simple(command, level, **kwargs)
    parts = []
    kwargs.each { |kw, value|
      next if value.nil?

      if value.is_a?(Color) || value.is_a?(Tone)
        parts << color_for_command(value)
      else
        parts << kw.to_s + ": " + value.inspect
      end
    }
    return command_indented_simple(command, parts, level)
  end

  def command_simple(function, count, command, level)
    raise "unexpected command parameters" if command.parameters.count != count
    value = indent(level) + function
    unless count == 0
      value += " "
      (0...count).each do |i|
        value += ", " unless i == 0
        value += command.parameters[i].inspect
      end
    end
    value += "\n"
    return value
  end

  def color_for_command(color)
    text = "red: " + color.red.to_i.inspect + ", "
    text += "green: " + color.green.to_i.inspect + ", "
    text += "blue: " + color.blue.to_i.inspect
    if color.is_a?(Tone)
      text += ", gray:" + color.gray.to_i.inspect if color.gray != 0.0
    elsif color.is_a?(Color)
      text += ", alpha:" + color.alpha.to_i.inspect if color.alpha != 0.0
    end
    return text
  end

  def command_text(commands, level)
    return command_indented_simple("text", commands.map { |command|
      raise "unexpected command parameters" if command.parameters.count != 1
      next command.parameters[0].inspect
    }, level)
  end

  def command_comment(commands, level)
    return command_indented_simple("comment", commands.map { |command|
      raise "unexpected command parameters" if command.parameters.count != 1
      next command.parameters[0].inspect
    }, level)
  end

  def command_script(commands, level)
    if commands.count == 1
      value = indent(level) + "script "
      raise "unexpected command parameters" if commands[0].parameters.count != 1
      value += commands[0].parameters[0].inspect + "\n"
      return value
    end
    command = "script \""
    spacer = "\n" + indent(level) + " " * command.length
    value = indent(level) + command
    value += commands.map { |command|
      raise "unexpected command parameters" if command.parameters.count != 1
      next command.parameters[0].inspect.delete_prefix("\"").delete_suffix("\"")
    }.join(spacer)
    value += "\"\n"
    return value
  end

  def command_scroll_map(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    return command_parameterized_simple("scroll_map", level,
                                        direction: RPGFactory::DIRECTION[command.parameters[0]],
                                        distance: command.parameters[1],
                                        speed: command.parameters[2])
  end

  def command_change_picture_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    return command_parameterized_simple("change_picture_tone", level,
                                        number: command.parameters[0],
                                        color: command.parameters[1],
                                        frames: command.parameters[2] )
  end

  def command_change_fog_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    return command_parameterized_simple("change_fog_tone", level,
                                        color: command.parameters[0],
                                        frames: command.parameters[1] )
  end

  def command_change_fog_opacity(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    return command_parameterized_simple("change_fog_opacity", level,
                                        opacity: command.parameters[0],
                                        frames: command.parameters[1] )
  end

  def command_change_tone(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    return command_parameterized_simple("change_tone", level,
                                        color: command.parameters[0],
                                        frames: command.parameters[1] )
  end

  def command_screen_flash(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    return command_parameterized_simple("screen_flash", level,
                                        color: command.parameters[0],
                                        frames: command.parameters[1] )
  end

  def command_screen_shake(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    return command_parameterized_simple("screen_shake", level,
                                        power: command.parameters[0],
                                        speed: command.parameters[1],
                                        frames: command.parameters[2])
  end

  def command_show_animation(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + character(command.parameters[0]) + ".show_animation "
    value += "anim(" + command.parameters[1].inspect + ")"
    value += "\n"
    return value
  end

  def command_audio(function, command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + function + " "
    value += audio(command.parameters[0])
    value += "\n"
    return value
  end

  def command_fade_out_bgm(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    return command_parameterized_simple("fade_out_bgm", level,
                                        seconds: command.parameters[0])
  end

  def command_fade_out_bgs(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    return command_parameterized_simple("fade_out_bgs", level,
                                        seconds: command.parameters[0])
  end

  def command_transfer_player(command, level)
    raise "unexpected command parameters" if command.parameters.count != 6
    parts = []
    if command.parameters[0] == 0
      parts << "map: " + command.parameters[1].inspect
      parts << "x: " + command.parameters[2].inspect
      parts << "y: " + command.parameters[3].inspect
    else
      parts << "map: variables[" + command.parameters[1].inspect + "]"
      parts << "x: variables[" + command.parameters[2].inspect + "]"
      parts << "y: variables[" + command.parameters[3].inspect + "]"
    end
    parts << "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect
    parts << "fading: " + (command.parameters[5] == 0 ? 'true' : 'false')
    return command_indented_simple("transfer_player", parts, level)
  end

  def command_event_location(command, level)
    raise "unexpected command parameters" if command.parameters.count != 5
    char = character(command.parameters[0])
    command_name = "set_event_location"
    parts = []
    if command.parameters[1] == 0
      parts << "x: " + command.parameters[2].inspect
      parts << "y: " + command.parameters[3].inspect
    elsif command.parameters[1] == 1
      parts << "x: variables[" + command.parameters[2].inspect + "]"
      parts << "y: variables[" + command.parameters[3].inspect + "]"
    else
      command_name = "swap_event_locations"
      parts << "target: " + character(command.parameters[2])
    end
    parts << "direction: " + RPGFactory::DIRECTION[command.parameters[4]].inspect
    return command_indented_simple(char + "." + command_name, parts, level)
  end

  def command_input_number(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "input_number "
    value += "variables[" + command.parameters[0].inspect + "], "
    value += "digits: " + command.parameters[1].inspect
    value += "\n"
    return value
  end

  def command_change_text_options(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "change_text_options "
    value += RPGFactory::TEXT_POSITION[command.parameters[0]].inspect + ", "
    value += RPGFactory::TEXT_WINDOW[command.parameters[1]].inspect
    value += "\n"
    return value
  end

  def command_button_input_processing(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "button_input_processing "
    value += "variables[" + command.parameters[0].inspect + "]"
    value += "\n"
    return value
  end

  def command_switch(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "switches[" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "] = " + RPGFactory::SWITCH_VALUE[command.parameters[2]].inspect
    value += "\n"
    return value
  end


  PROPERTY_NAMES_CHARACTERS = {
    0 => 'x',
    1 => 'y',
    2 => 'direction',
    3 => 'screen_x',
    4 => 'screen_y',
    5 => 'terrain_tag',
  }

  PROPERTY_NAMES_GLOBAL = {
    0 => 'map_id',
    1 => 'party_members',
    2 => 'player.gold',
    3 => 'steps',
    4 => 'play_time',
    5 => 'timer',
    6 => 'save_count',
  }

  def command_variable(command, level)
    value = indent(level) + "variables[" + command.parameters[0].inspect
    if command.parameters[0] != command.parameters[1]
      value += ".." + command.parameters[1].inspect
    end
    value += "] " + RPGFactory::OPERATION[command.parameters[2]] + " "
    case command.parameters[3]
    when 0
      value += command.parameters[4].inspect
    when 1
      value += "variables[" + command.parameters[4].inspect + "]"
    when 2
      value += command.parameters[4].inspect + ".." + command.parameters[5].inspect
    when 3
      value += "items" + command.parameters[4..].inspect
    when 4
      value += "actors" + command.parameters[4..].inspect
    when 5
      value += "enemies" + command.parameters[4..].inspect
    when 6
      value += character(command.parameters[4]) + "." + PROPERTY_NAMES_CHARACTERS[command.parameters[5]]
    when 7
      value += PROPERTY_NAMES_GLOBAL[command.parameters[4]]
    end
    value += "\n"
    return value
  end

  def command_self_switch(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    value = indent(level) + "self_switch[" + command.parameters[0].inspect + "] "
    value += "= " + RPGFactory::SWITCH_VALUE[command.parameters[1]].inspect
    value += "\n"
    return value
  end

  def command_timer(command, level)
    value = indent(level)
    if command.parameters[0] == 0
      raise "unexpected command parameters" if command.parameters.count != 2
      value += "start_timer "
      value += command.parameters[1].inspect
      value += "\n"
    else
      raise "unexpected command parameters" if command.parameters.count != 1
      value += "stop_timer\n"
    end
    return value
  end

  def command_change_gold(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3
    value = indent(level) + "player.gold "
    value += RPGFactory::GOLD_OPERATION[command.parameters[0]] + " "

    case command.parameters[1]
    when 0
      value += command.parameters[2].inspect
    when 1
      value += "variables[" + command.parameters[2].inspect + "]"
    end

    value += "\n"
    return value
  end

  def command(command, level)
    command.parameters.each do |parameter|
      # raise "missing when for command code " + command.code.to_s if parameter.inspect.start_with?('#')
    end
    value = indent(level) + "command(" + command.code.inspect
    command.parameters.each do |parameter|
      value += ", " + parameter.inspect
    end
    value += ")\n"
    return value
  end

  def move_dsl(move, level)
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
    when 14 then return "jump_to x: " + move.parameters[0].inspect + ", y: " + move.parameters[1].inspect
    when 15 then return "wait " + move.parameters[0].inspect
    when 16 then return "face_down"
    when 17 then return "face_left"
    when 18 then return "face_right"
    when 19 then return "face_up"
    when 20 then return "turn_right"
    when 21 then return "turn_left"
    when 22 then return "turn_around"
    when 23 then return "turn_randomly"
    when 24 then return "face_randomly"
    when 25 then return "face_toward_player"
    when 26 then return "face_away_from_player"
    when 27 then return "switches[" + move.parameters[0].inspect + "] = :ON"
    when 28 then return "switches[" + move.parameters[0].inspect + "] = :OFF"
    when 29 then return "change_speed " + move.parameters[0].inspect
    when 30 then return "change_frequency " + move.parameters[0].inspect
    when 31 then return "animate_walking"
    when 32 then return "animate_walking false"
    when 33 then return "animate_steps"
    when 34 then return "animate_steps false"
    when 35 then return "lock_direction"
    when 36 then return "lock_direction false"
    when 37 then return "set_intangible"
    when 38 then return "set_intangible false"
    when 39 then return "set_always_foreground"
    when 40 then return "set_always_foreground false"
    when 41
      parameters = []
      parameters.append "name: " + move.parameters[0].inspect if move.parameters[0] != ""
      parameters.append "hue: " + move.parameters[1].inspect if move.parameters[1] != 0
      parameters.append "direction: " + RPGFactory::DIRECTION[move.parameters[2]].inspect if move.parameters[2] != 2
      parameters.append "pattern: " + move.parameters[3].inspect if move.parameters[3] != 0
      return "remove_graphic" if parameters == []
      return "set_character " + parameters.join(", ")
    when 42 then return "set_opacity " + move.parameters[0].inspect
    when 43 then return "set_blend_type " + RPGFactory::BLENDING[move.parameters[0]].inspect
    when 44 then return "play_se " + audio(move.parameters[0])
    when 45 then return "script " + move.parameters[0].inspect
    else
      value = "command(" + move.code.inspect
      move.parameters.each do |parameter|
        value += ", " + parameter.inspect
      end
      value += ")"
      return value
    end
  end

  def command_condition(command, empty, level)
    value = indent(level) + "branch("
    type = RPGFactory::CONDITION_TYPE[command.parameters[0]]

    case type
    when :switch
      raise "unexpected command parameters" if command.parameters.count != 3
      value += "switches[" + command.parameters[1].inspect + "], "
      value += RPGFactory::SWITCH_VALUE[command.parameters[2]].inspect
    when :variable
      raise "unexpected command parameters" if command.parameters.count != 5
      value += "variables[" + command.parameters[1].inspect + "], "
      value += RPGFactory::COMPARISON[command.parameters[4]].inspect + ", "
      if command.parameters[2] == 0
        value += command.parameters[3].inspect
      else
        value += "variables[" + command.parameters[3].inspect + "]"
      end
    when :self_switch
      raise "unexpected command parameters" if command.parameters.count != 3
      value += command.parameters[1].inspect + ", "
      value += RPGFactory::SWITCH_VALUE[command.parameters[2]].inspect
    when :timer
      raise "unexpected command parameters" if command.parameters.count != 3
      value += "timer, "
      value += RPGFactory::SIMPLE_COMPARISON[command.parameters[2]].inspect + ", "
      value += command.parameters[1].inspect
    when :character
      raise "unexpected command parameters" if command.parameters.count != 3
      value += character(command.parameters[1]) + ", "
      value += RPGFactory::DIRECTION[command.parameters[2]].inspect
    when :gold
      raise "unexpected command parameters" if command.parameters.count != 3
      value += "player.gold, "
      value += RPGFactory::SIMPLE_COMPARISON[command.parameters[2]].inspect + ", "
      value += command.parameters[1].inspect
    when :button
      raise "unexpected command parameters" if command.parameters.count != 2
      value += RPGFactory::BUTTON[command.parameters[1]].inspect
    when :script
      raise "unexpected command parameters" if command.parameters.count != 2
      value += command.parameters[1].inspect
    else
      # TODO print a warning that this condition type isn't supported
      # raise "unexpected condition type " + type.to_s
      value += "{\n"
      value += indent(level + 1) + "type: " + type.inspect + ",\n"
      value += indent(level + 1) + "parameters: " + command.parameters[1..].inspect + " }\n"
      value += indent(level)
    end

    value += ") {"
    if empty
      value += "}"
    end
    value += "\n"

    return value
  end

  def command_loop(command, empty, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level) + "loop {"
    if empty
      value += "}"
    end
    value += "\n"
    return value
  end

  def command_show_choices(command, level, text: nil)
    value = indent(level) + "show_choices"
    if text
      value += "(" + text.inspect + ") {\n"
    else
      value += " {\n"
    end
    return value
  end

  def command_when(command, empty, current_cancellation, current_choices, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    choice_type = "choice"
    choice_type = "default_choice" if command.parameters[0] + 1 == current_cancellation

    value = indent(level) + choice_type + "(" + current_choices[command.parameters[0]].inspect + ") {"
    value += "}" if empty
    value += "\n"
    return value
  end

  def command_when_cancel(command, empty, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level) + "when_cancel {"
    value += "}" if empty
    value += "\n"
    return value
  end

  def command_battle(command, level)
    value = indent(level) + "battle"
    unless command.parameters.empty?
      value += "(" + command.parameters.map(&:inspect).join(", ") + ")"
    end
    value += " {"
    return value
  end

  def command_battle_win(command, empty, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "when_win {\n"
    return value
  end

  def command_battle_escape(command, empty, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "when_escape {\n"
    return value
  end

  def command_battle_lose(command, empty, level)
    raise "unexpected command parameters" if command.parameters.count != 0
    value = indent(level + 1) + "when_lose {\n"
    return value
  end

  def command_move_route(command, next_wait, level)
    raise "unexpected command parameters" if command.parameters.count != 2
    route = command.parameters[1]
    last = route.list.pop
    value = indent(level) + character(command.parameters[0]) + ".set_move_route {"
    raise "unexpected last route command" unless objects_equal?(last, DEFAULT_MOVE)
    if route.list.empty? && !route.repeat && !route.skippable
      value += "}"
      value += ".wait" if next_wait
      value += "\n"
      return value
    end

    value += "\n"
    value += indent(level + 1) + "mark_as_repeat\n" if route.repeat
    value += indent(level + 1) + "mark_as_skippable\n" if route.skippable
    route.list.each do |move|
      value += indent(level + 1) + move_dsl(move, level + 1) + "\n"
    end
    value += indent(level) + "}"
    value += ".wait" if next_wait
    value += "\n"
    return value
  end

  # will get to this one
  def command_change_map_settings(command, level)
    if command.parameters[0] == 0
      raise "unexpected command parameters" if command.parameters.count != 3
      return command_parameterized_simple("change_panorama", level,
                                          graphic: command.parameters[1],
                                          hue: command.parameters[2])
    elsif command.parameters[0] == 1
      raise "unexpected command parameters" if command.parameters.count != 8
      return command_parameterized_simple("change_fog", level,
                                          graphic: command.parameters[1],
                                          hue: command.parameters[2],
                                          opacity: command.parameters[3],
                                          blending: RPGFactory::BLENDING[command.parameters[4]] || :normal,
                                          zoom: command.parameters[5],
                                          sx: command.parameters[6] != 0 ? command.parameters[6] : nil,
                                          sy: command.parameters[7] != 0 ? command.parameters[7] : nil)
    else
      raise "unexpected command parameters" if command.parameters.count != 2
      return command_parameterized_simple("change_battleback", level,
                                          graphic: command.parameters[1])
    end
  end

  def command_show_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 10
    parts = []
    parts << "number: " + command.parameters[0].inspect
    parts << "graphic: " + command.parameters[1].inspect
    parts << "origin: " + RPGFactory::ORIGIN[command.parameters[2]].inspect
    if command.parameters[3] == 0
      parts << "x: " + command.parameters[4].inspect
      parts << "y: " + command.parameters[5].inspect
    else
      parts << "x: variables[" + command.parameters[4].inspect + "]"
      parts << "y: variables[" + command.parameters[5].inspect + "]"
    end
    parts << "zoom_x: " + command.parameters[6].inspect if command.parameters[6] != 100
    parts << "zoom_y: " + command.parameters[7].inspect if command.parameters[7] != 100
    parts << "opacity: " + command.parameters[8].inspect if command.parameters[8] != 255
    parts << "blending: " + RPGFactory::BLENDING[command.parameters[9]].inspect
    return command_indented_simple("show_picture", parts, level)
  end

  def command_move_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 10
    parts = []
    parts << "number: " + command.parameters[0].inspect
    parts << "frames: " + command.parameters[1].inspect
    parts << "origin: " + RPGFactory::ORIGIN[command.parameters[2]].inspect
    if command.parameters[3] == 0
      parts << "x: " + command.parameters[4].inspect if command.parameters[4] != 0
      parts << "y: " + command.parameters[5].inspect if command.parameters[5] != 0
    else
      parts << "x: variables[" + command.parameters[4].inspect + "]"
      parts << "y: variables[" + command.parameters[5].inspect + "]"
    end
    parts << "zoom_x: " + command.parameters[6].inspect if command.parameters[6] != 100
    parts << "zoom_y: " + command.parameters[7].inspect if command.parameters[7] != 100
    parts << "opacity: " + command.parameters[8].inspect if command.parameters[8] != 255
    parts << "blending: " + RPGFactory::BLENDING[command.parameters[9]].inspect
    return command_indented_simple("move_picture", parts, level)
  end

  def command_rotate_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 2

    return command_parameterized_simple("rotate_picture", level,
                                        number: command.parameters[0],
                                        speed: command.parameters[1])
  end

  def command_erase_picture(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    return command_parameterized_simple("erase_picture", level,
                                        number: command.parameters[0])
  end

  def command_weather_effect(command, level)
    raise "unexpected command parameters" if command.parameters.count != 3

    return command_parameterized_simple("weather_effect", level,
                                        weather: RPGFactory::WEATHER[command.parameters[0]],
                                        power: command.parameters[1],
                                        frames: command.parameters[2])
  end

  def command_change_transparent_flag(command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + "change_transparent_flag "
    value += RPGFactory::TRANSPARENT_FLAG[command.parameters[0]].inspect
    value += "\n"
    return value
  end

  def command_access(function, command, level)
    raise "unexpected command parameters" if command.parameters.count != 1
    value = indent(level) + function + " "
    value += RPGFactory::ACCESS[command.parameters[0]].inspect
    value += "\n"
    return value
  end
end
