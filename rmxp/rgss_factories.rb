def map(
  data:,
  events:,
  tileset_id: 1,
  autoplay_bgm: false,
  bgm: RPG::AudioFile.new,
  autoplay_bgs: false,
  bgs: RPG::AudioFile.new("", 80),
  encounter_list: [],
  encounter_step: 30
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
  name: "",
  volume: 100,
  pitch: 100
)
  return RPG::AudioFile.new(name, volume, pitch)
end

def event(id:, name:, x:, y:, pages: [])
  event = RPG::Event.new(x, y)
  event.id = id
  event.name = name
  pages.append page() if pages == []
  event.pages = pages
  return event
end

def table(x:, y: 0, z: 0, data: [])
  table = Table.new(x, y, z)
  table.data = data
  return table
end

EVENT_MOVE_TYPE = {
  0 => :fixed,
  1 => :random,
  2 => :approach,
  3 => :custom,
}

EVENT_MOVE_TYPE_INVERSE = EVENT_MOVE_TYPE.invert

EVENT_TRIGGER = {
  0 => :action,
  1 => :player_touch,
  2 => :event_touch,
  3 => :autorun,
  4 => :parallel,
}

EVENT_TRIGGER_INVERSE = EVENT_TRIGGER.invert

def page(
  condition: RPG::Event::Page::Condition.new,
  graphic: RPG::Event::Page::Graphic.new,
  move_type: :fixed,
  move_speed: 3,
  move_frequency: 3,
  move_route: RPG::MoveRoute.new,
  walk_anime: true,
  step_anime: false,
  direction_fix: false,
  through: false,
  always_on_top: false,
  trigger: :action,
  list: []
)
  page = RPG::Event::Page.new
  page.condition = condition
  page.graphic = graphic
  page.move_type = EVENT_MOVE_TYPE_INVERSE[move_type]
  page.move_speed = move_speed
  page.move_frequency = move_frequency
  page.move_route = move_route
  page.walk_anime = walk_anime
  page.step_anime = step_anime
  page.direction_fix = direction_fix
  page.through = through
  page.always_on_top = always_on_top
  page.trigger = EVENT_TRIGGER_INVERSE[trigger]
  list.append RPG::EventCommand.new
  page.list = list.flatten
  return page
end

def command(
  code,
  *parameters
)
  return RPG::EventCommand.new(code, 0, parameters)
end

def end_block()
  command = command(0)
  command.indent += 1
  return command
end

# TODO: lossy change - simplify page_condition to
# page_condition(
#   switch1: switch(id),
#   switch2: switch(id),
#   variable: variable(id),
#   variable_at_least: value,
#   self_switch: "A",
# )
def page_condition(
  switch1_valid: false,
  switch2_valid: false,
  variable_valid: false,
  self_switch_valid: false,
  switch1_id: 1,
  switch2_id: 1,
  variable_id: 1,
  variable_value: 0,
  self_switch_ch: "A"
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

GRAPHIC_DIRECTION = {
  2 => :down,
  4 => :left,
  6 => :right,
  8 => :up,
}

GRAPHIC_DIRECTION_INVERSE = GRAPHIC_DIRECTION.invert

def graphic(
  tile_id: 0,
  character_name: "",
  character_hue: 0,
  direction: :down,
  pattern: 0,
  opacity: 255,
  blend_type: 0
)
  graphic = RPG::Event::Page::Graphic.new
  graphic.tile_id = tile_id
  graphic.character_name = character_name
  graphic.character_hue = character_hue
  graphic.direction = GRAPHIC_DIRECTION_INVERSE[direction]
  graphic.pattern = pattern
  graphic.opacity = opacity
  graphic.blend_type = blend_type
  return graphic
end

def route(
  *list,
  repeat: true,
  skippable: false
)
  route = RPG::MoveRoute.new
  route.repeat = repeat
  route.skippable = skippable
  list.append RPG::MoveCommand.new
  route.list = list
  return route
end

def move(
  code:,
  parameters: []
)
  move = RPG::MoveCommand.new
  move.code = code
  move.parameters = parameters
  return move
end

def script(*parts)
  commands = parts.map { |text| command(655, text) }
  commands[0].code = 355
  return commands
end

def text(*parts)
  commands = parts.map { |text| command(401, text) }
  commands[0].code = 101
  return commands
end

def wait(time)
  return command(106, time)
end

def play_se(audio)
  return command(250, audio)
end

def change_tone(red:, green:, blue:, gray: 0, frames:)
  return command(223, Tone.new(red, green, blue, gray), frames)
end

def screen_flash(red:, green:, blue:, alpha: 0, frames:)
  return command(224, Color.new(red, green, blue, alpha), frames)
end

TRANSFER_DIRECTION = {
  0 => :retain,
  1 => :down,
  2 => :left,
  3 => :right,
  4 => :up,
}

TRANSFER_DIRECTION_INVERSE = TRANSFER_DIRECTION.invert

def transfer_player(map:, x:, y:, direction:, fading:)
  return command(201, 0, map, x, y, TRANSFER_DIRECTION_INVERSE[direction], fading ? 0 : 1)
end

def transfer_player_variables(map:, x:, y:, direction:, fading:)
  return command(201, 1, map, x, y, TRANSFER_DIRECTION_INVERSE[direction], fading ? 0 : 1)
end

# TODO: lossy change - skip else block when args[:else] == []
def condition(parameters: [], **args)
  commands = []
  commands.append command(111, *parameters)

  args[:then].each do |command|
    command.indent += 1
    commands.append command
  end
  commands.append end_block

  if args[:else] != nil
    commands.append command(411)
    args[:else].each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block
  end

  commands.append command(412)
  return commands
end

def show_choices(choices:, cancellation:, choice1: [], choice2: [], choice3: [], choice4: [], cancel: [])
  commands = []
  commands.append command(102, choices, cancellation)

  commands.append command(402, 0, choices[0])
  choice1.each do |command|
    command.indent += 1
    commands.append command
  end
  commands.append end_block

  if choices.count >= 2
    commands.append command(402, 1, choices[1])
    choice2.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block
  end

  if choices.count >= 3
    commands.append command(402, 2, choices[2])
    choice3.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block
  end

  if choices.count >= 4
    commands.append command(402, 3, choices[3])
    choice4.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block
  end

  if cancellation == 5
    commands.append command(403)
    cancel.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block
  end

  commands.append command(404)
  return commands
end

def move_route(character: 0, route:)
  commands = []
  commands.append command(209, character, route)
  route.list.each do |move|
    commands.append command(509, move)
  end
  commands.pop
  return commands
end
