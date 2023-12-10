require_relative 'rmxp/rgss'
require_relative 'rmxp/rgss_factories'
require_relative 'src/common'

data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map369 - Critical Capture.yaml')
# data = load_yaml('C:\Projects\Reborn\Reborn\DataExport/Map006 - Department Store 11F.yaml')

INDENT_SIZE = 2

def indent(level)
  return ' ' * level * INDENT_SIZE
end

def save_rb(file, data)
  save_yaml('var/map_original_tmp.yaml', data)
  yaml_stable_ref('var/map_original_tmp.yaml', 'var/map_original.yaml')
  marshal = Marshal.dump(data)
  ruby = dump_rb(data, 0)
  File.write('var/map.rb', ruby)
  # print_rb(ruby)
  reconstructed = eval(ruby)
  save_yaml('var/map_tmp.yaml', reconstructed)
  yaml_stable_ref('var/map_tmp.yaml', 'var/map.yaml')
  puts marshal == Marshal.dump(reconstructed)
  puts Marshal.dump(data) == Marshal.dump(reconstructed)
  puts File.read('var/map_original.yaml') == File.read('var/map.yaml')
end

def print_rb(code)
  code.lines.each_with_index do |line, key|
    puts key.to_s.rjust(6, ' ') + '  '+ line
  end
end

def dump_rb(object, level)
  case object
  when RPG::Map
    return dump_map(object, level)
  end
end

DEFAULT_AUDIO = Marshal.dump(RPG::AudioFile.new)
DEFAULT_BGS = Marshal.dump(RPG::AudioFile.new("", 80))
DEFAULT_CONDITION = Marshal.dump(RPG::Event::Page::Condition.new)
DEFAULT_GRAPHIC = Marshal.dump(RPG::Event::Page::Graphic.new)
DEFAULT_COMMAND = Marshal.dump(RPG::EventCommand.new)
DEFAULT_ROUTE = Marshal.dump(RPG::MoveRoute.new)
DEFAULT_MOVE = Marshal.dump(RPG::MoveCommand.new)

def dump_map(map, level)
  value = "map(\n"
  value += indent(level + 1) + "tileset_id: " + map.tileset_id.inspect + ",\n" if map.tileset_id != 1
  value += indent(level + 1) + "autoplay_bgm: " + map.autoplay_bgm.inspect + ",\n" if map.autoplay_bgm != false
  value += indent(level + 1) + "bgm: " + dump_audio(map.bgm, level + 1) + ",\n" if Marshal.dump(map.bgm) != DEFAULT_AUDIO
  value += indent(level + 1) + "autoplay_bgs: " + map.autoplay_bgs.inspect + ",\n" if map.autoplay_bgs != false
  value += indent(level + 1) + "bgs: " + dump_audio(map.bgs, level + 1) + ",\n" if Marshal.dump(map.bgs) != DEFAULT_BGS
  raise "non-empty map encounter_list" if map.encounter_list != []
  value += indent(level + 1) + "encounter_step: " + map.encounter_step.inspect + ",\n" if map.encounter_step != 30
  value += indent(level + 1) + "data: " + dump_table(map.data, level + 1) + ",\n"
  value += indent(level + 1) + "events: [\n\n"
  map.events.each do |key, event|
    value += indent(level + 2) + dump_event(event, level + 2) + ",\n\n"
  end
  value += indent(level + 1) + "],\n"
  value += indent(level) + ")"
  return value
end

def dump_audio(audio, level)
  value = "audio("
  parameters = []
  parameters.append "name: " + audio.name.inspect if audio.name != ""
  parameters.append "volume: " + audio.volume.inspect if audio.volume != 100
  parameters.append "pitch: " + audio.pitch.inspect if audio.pitch != 100
  value += parameters.join(", ")
  value += ")"
  return value
end

def dump_table(table, level)
  value = "table(\n"
  value += indent(level + 1) + "x: " + table.xsize.inspect + ",\n"
  value += indent(level + 1) + "y: " + table.ysize.inspect + ",\n" if table.ysize > 1
  value += indent(level + 1) + "z: " + table.zsize.inspect + ",\n" if table.zsize > 1
  value += indent(level + 1) + "data: " + table.data.inspect + ",\n"
  value += indent(level) + ")"
  return value
end

def dump_event(event, level)
  value = "event(\n"
  value += indent(level + 1) + "id: " + event.id.inspect + ",\n"
  value += indent(level + 1) + "name: " + event.name.inspect + ",\n"
  value += indent(level + 1) + "x: " + event.x.inspect + ",\n"
  value += indent(level + 1) + "y: " + event.y.inspect + ",\n"
  value += indent(level + 1) + "pages: [\n"
  event.pages.each do |page|
    value += indent(level + 2) + dump_page(page, level + 2) + ",\n"
  end
  value += indent(level + 1) + "],\n"
  value += indent(level) + ")"
  return value
end

def dump_page(page, level)
  value = "page(\n"
  value += indent(level + 1) + "condition: " + dump_page_condition(page.condition, level + 1) + ",\n" if Marshal.dump(page.condition) != DEFAULT_CONDITION
  value += indent(level + 1) + "graphic: " + dump_graphic(page.graphic, level + 1) + ",\n" if Marshal.dump(page.graphic) != DEFAULT_GRAPHIC
  value += indent(level + 1) + "move_type: " + page.move_type.inspect + ",\n" if page.move_type != 0
  value += indent(level + 1) + "move_speed: " + page.move_speed.inspect + ",\n" if page.move_speed != 3
  value += indent(level + 1) + "move_frequency: " + page.move_frequency.inspect + ",\n" if page.move_frequency != 3
  value += indent(level + 1) + "move_route: " + dump_route(page.move_route, level + 1) + ",\n" if Marshal.dump(page.move_route) != DEFAULT_ROUTE
  value += indent(level + 1) + "walk_anime: " + page.walk_anime.inspect + ",\n" if page.walk_anime != true
  value += indent(level + 1) + "step_anime: " + page.step_anime.inspect + ",\n" if page.step_anime != false
  value += indent(level + 1) + "direction_fix: " + page.direction_fix.inspect + ",\n" if page.direction_fix != false
  value += indent(level + 1) + "through: " + page.through.inspect + ",\n" if page.through != false
  value += indent(level + 1) + "always_on_top: " + page.always_on_top.inspect + ",\n" if page.always_on_top != false
  value += indent(level + 1) + "trigger: " + page.trigger.inspect + ",\n" if page.trigger != 0
  commands = page.list.clone
  last = commands.pop
  raise "unexpected last event command" if Marshal.dump(last) != DEFAULT_COMMAND
  if page.list.count != 0
    value += indent(level + 1) + "list: [\n"
    value += dump_command_list(commands, level + 2)
    value += indent(level + 1) + "],\n"
  end
  value += indent(level) + ")"
  return value
end

def dump_page_condition(condition, level)
  value = "page_condition(\n"
  value += indent(level + 1) + "switch1_valid: " + condition.switch1_valid.inspect + ",\n" if condition.switch1_valid != false
  value += indent(level + 1) + "switch2_valid: " + condition.switch2_valid.inspect + ",\n" if condition.switch2_valid != false
  value += indent(level + 1) + "variable_valid: " + condition.variable_valid.inspect + ",\n" if condition.variable_valid != false
  value += indent(level + 1) + "self_switch_valid: " + condition.self_switch_valid.inspect + ",\n" if condition.self_switch_valid != false
  value += indent(level + 1) + "switch1_id: " + condition.switch1_id.inspect + ",\n" if condition.switch1_id != 1
  value += indent(level + 1) + "switch2_id: " + condition.switch2_id.inspect + ",\n" if condition.switch2_id != 1
  value += indent(level + 1) + "variable_id: " + condition.variable_id.inspect + ",\n" if condition.variable_id != 1
  value += indent(level + 1) + "variable_value: " + condition.variable_value.inspect + ",\n" if condition.variable_value != 0
  value += indent(level + 1) + "self_switch_ch: " + condition.self_switch_ch.inspect + ",\n" if condition.self_switch_ch != "A"
  value += indent(level) + ")"
  return value
end

def dump_command_list(commands, level)
  value = ""
  i = 0
  while i < commands.count
    command = commands[i]
    case command.code
    when 0 # block end
      level -= 2
      value += indent(level + 1) + "],\n"
    when 101 # text
      parts = collect(commands, i + 1, 401)
      i += parts.count
      parts.unshift(command)
      value += dump_command_array('text', parts, level)
    when 102 # show choices
      value += dump_command_show_choices(command, level)
    when 402 # show choices - when
      value += dump_command_when(command, level)
      level += 2
    when 403 # show choices - when cancel
      value += dump_command_when_cancel(command, level)
      level += 2
    when 404 # show choices - end
      value += indent(level) + "),\n"
    when 106 # wait
      value += dump_command_wait(command, level)
    when 111 # if
      value += dump_command_condition(command, level)
      level += 2
    when 201 # transfer player
      value += dump_command_transfer_player(command, level)
    when 209 # move route
      parts = collect(commands, i + 1, 509)
      i += parts.count
      value += dump_command_move_route(command, level)
    when 223 # change screen color tone
      value += dump_command_change_tone(command, level)
    when 224 # screen flash
      value += dump_command_screen_flash(command, level)
    when 250 # play se
      value += dump_command_play_se(command, level)
    when 355 # script
      parts = collect(commands, i + 1, 655)
      i += parts.count
      parts.unshift(command)
      value += dump_command_array('script', parts, level)
    when 411 # else
      value += indent(level + 1) + "else_commands: [\n"
      level += 2
    when 412 # branch end
      value += indent(level) + "),\n"
    else
      value += dump_command(command, level)
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

def dump_command_array(function, commands, level)
  value = indent(level) + "*" + function + "(\n"
  commands.each do |command|
    raise "unexpected command parameters" if command.parameters.count != 1
    value += indent(level + 1) + command.parameters[0].inspect + ",\n"
  end
  value += indent(level) + "),\n"
  return value
end

def dump_command_change_tone(command, level)
  raise "unexpected command parameters" if command.parameters.count != 2
  value = indent(level) + "change_tone("
  value += "red: " + command.parameters[0].red.to_i.inspect + ", "
  value += "green: " + command.parameters[0].green.to_i.inspect + ", "
  value += "blue: " + command.parameters[0].blue.to_i.inspect + ", "
  value += "gray: " + command.parameters[0].gray.to_i.inspect + ", " if command.parameters[0].gray != 0.0
  value += "time: " + command.parameters[1].inspect
  value += "),\n"
  return value
end

def dump_command_screen_flash(command, level)
  raise "unexpected command parameters" if command.parameters.count != 2
  value = indent(level) + "screen_flash(\n"
  value += "red: " + command.parameters[0].red.to_i.inspect + ", "
  value += "green: " + command.parameters[0].green.to_i.inspect + ", "
  value += "blue: " + command.parameters[0].blue.to_i.inspect + ", "
  value += "alpha: " + command.parameters[0].alpha.to_i.inspect + ", " if command.parameters[0].alpha != 0.0
  value += "time: " + command.parameters[1].inspect
  value += indent(level) + "),\n"
  return value
end

def dump_command_play_se(command, level)
  raise "unexpected command parameters" if command.parameters.count != 1
  value = indent(level) + "play_se("
  value += dump_audio(command.parameters[0], level + 1)
  value += "),\n"
  return value
end

def dump_command_transfer_player(command, level)
  value = indent(level)
  value += "transfer_player(" if command.parameters[0] == 0
  value += "transfer_player_variables(" if command.parameters[0] == 1
  parameters = []
  parameters.append "map: " + command.parameters[1].inspect
  parameters.append "x: " + command.parameters[2].inspect
  parameters.append "y: " + command.parameters[3].inspect
  parameters.append "direction: " + dump_direction(command.parameters[4])
  parameters.append "fading: " + (command.parameters[5] == 0 ? 'true' : 'false')
  value += parameters.join(", ")
  value += "),\n"
  return value
end

def dump_direction(direction)
  case direction
  when 0
    return ':retain'
  when 1
    return ':down'
  when 2
    return ':left'
  when 3
    return ':right'
  when 4
    return ':up'
  end
end

def dump_command_wait(command, level)
  raise "unexpected command parameters" if command.parameters.count != 1
  value = indent(level) + "wait("
  value += command.parameters[0].inspect
  value += "),\n"
  return value
end

def dump_command(command, level)
  command.parameters.each do |parameter|
    raise "missing when for command code " + command.code.to_s if parameter.inspect.start_with?('#')
  end
  value = indent(level) + "command(\n"
  value += indent(level + 1) + command.code.inspect + ",\n"
  value += indent(level + 1) + command.parameters.inspect + ",\n"
  value += indent(level) + "),\n"
  return value
end

def dump_graphic(graphic, level)
  value = "graphic(\n"
  value += indent(level + 1) + "tile_id: " + graphic.tile_id.inspect + ",\n" if graphic.tile_id != 0
  value += indent(level + 1) + "character_name: " + graphic.character_name.inspect + ",\n" if graphic.character_name != ""
  value += indent(level + 1) + "character_hue: " + graphic.character_hue.inspect + ",\n" if graphic.character_hue != 0
  value += indent(level + 1) + "direction: " + graphic.direction.inspect + ",\n" if graphic.direction != 2
  value += indent(level + 1) + "pattern: " + graphic.pattern.inspect + ",\n" if graphic.pattern != 0
  value += indent(level + 1) + "opacity: " + graphic.opacity.inspect + ",\n" if graphic.opacity != 255
  value += indent(level + 1) + "blend_type: " + graphic.blend_type.inspect + ",\n" if graphic.blend_type != 0
  value += indent(level) + ")"
  return value
end

def dump_route(route, level)
  value = "route(\n"
  value += indent(level + 1) + "repeat: " + route.repeat.inspect + ",\n" if route.repeat != true
  value += indent(level + 1) + "skippable: " + route.skippable.inspect + ",\n" if route.skippable != false
  last = route.list.pop
  raise "unexpected last route command" if Marshal.dump(last) != DEFAULT_MOVE
  if route.list.count != 0
    value += indent(level + 1) + "list: [\n"
    route.list.each do |command|
      value += indent(level + 2) + dump_move(command, level + 2) + ",\n"
    end
    value += indent(level + 1) + "],\n"
  end
  value += indent(level) + ")"
  return value
end

def dump_move(move, level)
  value = "move(\n"
  value += indent(level + 1) + "code: " + move.code.inspect + ",\n"
  value += indent(level + 1) + "parameters: " + move.parameters.inspect + ",\n"
  value += indent(level) + ")"
  return value
end

def dump_command_condition(command, level)
  value = indent(level) + "*condition(\n"
  value += indent(level + 1) + "parameters: " + command.parameters.inspect + ",\n"
  value += indent(level + 1) + "then_commands: [\n"
  return value
end

def dump_command_show_choices(command, level)
  value = indent(level) + "*show_choices(\n"
  value += indent(level + 1) + "choices: " + command.parameters[0].inspect + ",\n"
  value += indent(level + 1) + "cancellation: " + command.parameters[1].inspect + ",\n"
  return value
end

def dump_command_when(command, level)
  raise "unexpected command parameters" if command.parameters.count != 2
  value = indent(level + 1) + "choice" + (command.parameters[0] + 1).to_s + ": [\n"
  return value
end

def dump_command_when_cancel(command, level)
  raise "unexpected command parameters" if command.parameters.count != 0
  value = indent(level + 1) + "cancel: [\n"
  return value
end

def dump_command_move_route(command, level)
  raise "unexpected command parameters" if command.parameters.count != 2
  value = indent(level) + "*move_route(\n"
  value += indent(level + 1) + "character: " + command.parameters[0].inspect + ",\n"
  value += indent(level + 1) + "route: " + dump_route(command.parameters[1], level + 1) + ",\n"
  value += indent(level) + "),\n"
  return value
end

save_rb('Map006 - Department Store 11F.rb', data)
