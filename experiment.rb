require_relative 'rmxp/rgss'
require_relative 'rmxp/rgss_factories'
require_relative 'src/common'

data = load_yaml('Map006 - Department Store 11F.yaml')

def indent(level)
  return ' ' * level * 2
end

def save_rb(file, data)
  puts dump_rb(data, 0)
end

def dump_rb(object, level)
  case object
  when RPG::Map
    return dump_map(object, level)
  end
end

def dump_map(object, level)
  object.events.each do |key, event|
    return indent(level + 1) + dump_event(event, level + 1)
  end
end

DEFAULT_CONDITION = Marshal.dump(RPG::Event::Page::Condition.new)
DEFAULT_GRAPHIC = Marshal.dump(RPG::Event::Page::Graphic.new)
DEFAULT_COMMAND = Marshal.dump(RPG::EventCommand.new)
DEFAULT_ROUTE = Marshal.dump(RPG::MoveRoute.new)
DEFAULT_MOVE = Marshal.dump(RPG::MoveCommand.new)

def dump_event(event, level)
  value = "event(\n"
  value += indent(level + 1) + "id: " + event.id.inspect + ",\n"
  value += indent(level + 1) + "name: " + event.name.inspect + ",\n"
  value += indent(level + 1) + "x: " + event.x.inspect + ",\n"
  value += indent(level + 1) + "y: " + event.y.inspect + ",\n"
  event.pages.each do |page|
    value += indent(level + 1) + dump_page(page, level + 1) + ",\n"
  end
  value += indent(level) + ")"
  return value
end

def dump_page(page, level)
  value = "page(\n"
  value += indent(level + 1) + "condition: " + dump_condition(page.condition, level + 1) + ",\n" if Marshal.dump(page.condition) != DEFAULT_CONDITION
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
  last = page.list.pop
  raise "unexpected last event command" if Marshal.dump(last) != DEFAULT_COMMAND
  if page.list.count != 0
    value += indent(level + 1) + "list: [\n"
    page.list.each do |command|
      value += indent(level + 2) + dump_command(command, level + 2) + ",\n"
    end
    value += indent(level + 1) + "],\n"
  end
  value += indent(level) + ")"
  return value
end

def dump_condition(condition, level)
  value = "condition(\n"
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

def dump_command(command, level)
  value = "command(\n"
  value += indent(level + 1) + "code: " + command.code.inspect + ",\n"
  value += indent(level + 1) + "indent: " + command.indent.inspect + ",\n"
  value += indent(level + 1) + "parameters: " + command.parameters.inspect + ",\n"
  value += indent(level) + ")"
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

save_rb('Map006 - Department Store 11F.rb', data)
