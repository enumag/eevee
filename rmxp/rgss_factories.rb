def map(
  data,
  events,
  tileset_id = 1,
  autoplay_bgm = false,
  bgm = RPG::AudioFile.new,
  autoplay_bgs = false,
  bgs = RPG::AudioFile.new("", 80),
  encounter_list = [],
  encounter_step = 30
)
  map = RPG::Map.new(data.xsize, data.ysize)
  map.tileset_id = tileset_id
  map.autoplay_bgm = autoplay_bgm
  map.bgm = bgm
  map.autoplay_bgs = autoplay_bgs
  map.bgs = bgs
  map.encounter_list = encounter_list
  map.encounter_step = encounter_step
  map.data = data
  events_hash = {}
  events.each do |event|
    events_hash[event.id] = event
  end
  map.events = events_hash
  return map
end

def audio(
  name = "",
  volume = 100,
  pitch = 100
)
  return RPG::AudioFile.new(name, volume, pitch)
end

def event(id, name, x, y, *pages)
  event = RPG::Event.new(x, y)
  event.id = id
  event.name = name
  event.pages = pages
  return event
end

def table(x, y = 0, z = 0, data = [])
  table = Table(x, y, z)
  table.data = data
  return table
end

def page(
  condition = RPG::Event::Page::Condition.new,
  graphic = RPG::Event::Page::Graphic.new,
  move_type = 0,
  move_speed = 3,
  move_frequency = 3,
  move_route = RPG::MoveRoute.new,
  walk_anime = true,
  step_anime = false,
  direction_fix = false,
  through = false,
  always_on_top = false,
  trigger = 0,
  list = []
)
  page = RPG::Event::Page.new
  page.condition = condition
  page.graphic = graphic
  page.move_type = move_type
  page.move_speed = move_speed
  page.move_frequency = move_frequency
  page.move_route = move_route
  page.walk_anime = walk_anime
  page.step_anime = step_anime
  page.direction_fix = direction_fix
  page.through = through
  page.always_on_top = always_on_top
  page.trigger = trigger
  list.append RPG::EventCommand.new
  page.list = list
  return page
end

def command(
  code = 0,
  indent = 0,
  parameters = []
)
  command = RPG::EventCommand.new
  command.code = code
  command.indent = indent
  command.parameters = parameters
  return command
end

def condition(
  switch1_valid = false,
  switch2_valid = false,
  variable_valid = false,
  self_switch_valid = false,
  switch1_id = 1,
  switch2_id = 1,
  variable_id = 1,
  variable_value = 0,
  self_switch_ch = "A"
)
  condition = RPG::Event::Page::Condition.new
  condition.switch1_valid = switch1_valid
  condition.switch2_valid = switch2_valid
  condition.variable_valid = variable_valid
  condition.self_switch_valid = self_switch_valid
  condition.switch1_id = switch1_id
  condition.switch2_id = switch2_id
  condition.variable_id = variable_id
  condition.variable_value = variable_value
  condition.self_switch_ch = self_switch_ch
  return condition
end

def graphic(
  tile_id = 0,
  character_name = "",
  character_hue = 0,
  direction = 2,
  pattern = 0,
  opacity = 255,
  blend_type = 0
)
  graphic = RPG::Event::Page::Graphic.new
  graphic.tile_id = tile_id
  graphic.character_name = character_name
  graphic.character_hue = character_hue
  graphic.direction = direction
  graphic.pattern = pattern
  graphic.opacity = opacity
  graphic.blend_type = blend_type
  return graphic
end

def route(
  repeat = true,
  skippable = false,
  list = []
)
  route = RPG::MoveRoute.new
  route.repeat = repeat
  route.skippable = skippable
  list.append RPG::MoveCommand.new
  route.list = list
  return route
end

def move(
  code = 0,
  parameters = []
)
  move = RPG::MoveCommand.new
  move.code = code
  move.parameters = parameters
  return move
end