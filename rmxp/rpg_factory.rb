class RPGFactory
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

  def variable(id)
    return id
  end

  def switch(id)
    return id
  end

  def audio(
    name: "",
    volume: 100,
    pitch: 100
  )
    return RPG::AudioFile.new(name, volume, pitch)
  end

  def event(id:, name:, x:, y:, **args)
    event = RPG::Event.new(x, y)
    event.id = id
    event.name = name
    pages = []
    args.each do |name, page|
      next unless name.start_with?("page")
      pages.append page
    end
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

  # TODO: lossy change - simplify conditions to this:
  # page(
  #   switch1: switch(id),
  #   switch2: switch(id),
  #   variable: variable(id),
  #   at_least: value,
  #   self_switch: "A",
  # )
  def page(
    switch1_valid: nil,
    switch2_valid: nil,
    variable_valid: nil,
    self_switch_valid: nil,
    switch1: nil,
    switch2: nil,
    variable: nil,
    at_least: 0,
    self_switch: nil,
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
    condition = RPG::Event::Page::Condition.new
    condition.switch1_valid = switch1_valid == nil ? switch1 != nil : switch1_valid
    condition.switch2_valid = switch2_valid == nil ? switch2 != nil : switch2_valid
    condition.variable_valid = variable_valid == nil ? variable != nil : variable_valid
    condition.self_switch_valid = self_switch_valid == nil ? self_switch != nil : self_switch_valid
    condition.switch1_id = switch1 != nil ? switch1 : 1
    condition.switch2_id = switch2 != nil ? switch2 : 1
    condition.variable_id = variable != nil ? variable : 1
    condition.variable_value = at_least
    condition.self_switch_ch = self_switch != nil ? self_switch : "A"

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
    graphic.direction = DIRECTION_INVERSE[direction]
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

  def script(script)
    parts = script.lines
    commands = parts.map { |text| command(655, text.chomp) }
    commands[0].code = 355
    return commands[0] if commands.length == 1
    return commands
  end

  def text(*parts)
    commands = parts.map { |text| command(401, text) }
    commands[0].code = 101
    return commands[0] if commands.length == 1
    return commands
  end

  def comment(*parts)
    commands = parts.map { |text| command(408, text) }
    commands[0].code = 108
    return commands[0] if commands.length == 1
    return commands
  end

  def input_number(variable, digits:)
    return command(103, variable, digits)
  end

  # TODO: this can use enums for improved serialization but it's rarely used
  def change_text_options(position, window)
    return command(104, position, window)
  end

  def button_input_processing(variable)
    return command(105, variable)
  end

  def wait(time)
    return command(106, time)
  end

  def wait_completion()
    return command(210)
  end

  def break_loop()
    return command(113)
  end

  def exit_event_processing()
    return command(115)
  end

  def erase_event()
    return command(116)
  end

  def call_common_event(id)
    return command(117, id)
  end

  def label(name)
    return command(118, name)
  end

  def jump_label(name)
    return command(119, name)
  end

  def battle_bgm(audio)
    return command(132, audio)
  end

  def battle_me(audio)
    return command(133, audio)
  end

  def play_bgm(audio)
    return command(241, audio)
  end

  def play_bgs(audio)
    return command(245, audio)
  end

  def play_me(audio)
    return command(249, audio)
  end

  def play_se(audio)
    return command(250, audio)
  end

  def fade_out_bgm(seconds:)
    return command(242, seconds)
  end

  def fade_out_bgs(seconds:)
    return command(246, seconds)
  end

  def change_tone(red:, green:, blue:, gray: 0, frames:)
    return command(223, Tone.new(red, green, blue, gray), frames)
  end

  def change_fog_tone(red:, green:, blue:, gray: 0, frames:)
    return command(205, Tone.new(red, green, blue, gray), frames)
  end

  def change_picture_tone(number:, red:, green:, blue:, gray: 0, frames:)
    return command(234, number, Tone.new(red, green, blue, gray), frames)
  end

  def screen_flash(red:, green:, blue:, alpha: 0, frames:)
    return command(224, Color.new(red, green, blue, alpha), frames)
  end

  def screen_shake(power:, speed:, frames:)
    return command(225, power, speed, frames)
  end

  DIRECTION = {
    0 => :retain,
    2 => :down,
    4 => :left,
    6 => :right,
    8 => :up,
  }

  DIRECTION_INVERSE = DIRECTION.invert

  def transfer_player(map:, x:, y:, direction:, fading:)
    return command(201, 0, map, x, y, DIRECTION_INVERSE[direction], fading ? 0 : 1)
  end

  def transfer_player_variables(map:, x:, y:, direction:, fading:)
    return command(201, 1, map, x, y, DIRECTION_INVERSE[direction], fading ? 0 : 1)
  end

  def event_location(character, x:, y:, direction:)
    return command(202, character, 0, x, y, DIRECTION_INVERSE[direction])
  end

  def event_location_variables(character, x:, y:, direction:)
    return command(202, character, 1, x, y, DIRECTION_INVERSE[direction])
  end

  def event_location_swap(character, target:, direction:)
    return command(202, character, 2, target, 0, DIRECTION_INVERSE[direction])
  end

  CONDITION_TYPE = {
    0 => :switch,
    1 => :variable,
    2 => :self_switch,
    3 => :timer,
    4 => :actor,
    5 => :enemy,
    6 => :character,
    7 => :gold,
    8 => :item,
    9 => :weapon,
    10 => :armor,
    11 => :button,
    12 => :script,
  }

  CONDITION_TYPE_INVERSE = CONDITION_TYPE.invert

  COMPARISON = {
    0 => "==",
    1 => ">=",
    2 => "<=",
    3 => ">",
    4 => "<",
    5 => "!=",
  }

  COMPARISON_INVERSE = COMPARISON.invert

  GOLD_COMPARISON = {
    0 => ">=",
    1 => "<=",
  }

  GOLD_COMPARISON_INVERSE = GOLD_COMPARISON.invert

  # TODO: lossy change - skip else block is empty
  # TODO: skip then block if empty
  def condition(**args)
    commands = []
    if args[:parameters] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[args[:type]], *args[:parameters])
    elsif args[:switch] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:switch], args[:switch], args[:value])
    elsif args[:self_switch] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:self_switch], args[:self_switch], args[:value])
    elsif args[:variable] != nil && args[:constant] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:variable], args[:variable], 0, args[:constant], COMPARISON_INVERSE[args[:operation]])
    elsif args[:variable] != nil && args[:other_variable] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:variable], args[:variable], 1, args[:other_variable], COMPARISON_INVERSE[args[:operation]])
    elsif args[:character] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:character], args[:character], DIRECTION_INVERSE[args[:facing]])
    elsif args[:gold] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:gold], args[:gold], GOLD_COMPARISON_INVERSE[args[:operation]])
    elsif args[:script] != nil
      commands.append command(111, CONDITION_TYPE_INVERSE[:script], args[:script])
    end

    args[:then] = [] if args[:then] == nil
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

  def player()
    return -1
  end

  def this()
    return 0
  end

  def character(id)
    return id
  end

  def repeat(**args)
    commands = []
    commands.append command(112)

    args[:commands].each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block

    commands.append command(413)
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

  def battle(parameters:, win: [], escape: nil, lose: [])
    commands = []
    commands.append command(301, *parameters)

    commands.append command(601)
    win.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block

    if escape != nil
      commands.append command(602)
      escape.each do |command|
        command.indent += 1
        commands.append command
      end
      commands.append end_block
    end

    commands.append command(603)
    lose.each do |command|
      command.indent += 1
      commands.append command
    end
    commands.append end_block

    commands.append command(604)
    return commands
  end

  def move_route(character, route)
    commands = []
    commands.append command(209, character, route)
    route.list.each do |move|
      commands.append command(509, move)
    end
    commands.pop
    return commands
  end

  OPERATION = {
    0 => "=",
    1 => "+=",
    2 => "-=",
    3 => "*=",
    4 => "/=",
    5 => "%=",
  }

  OPERATION_INVERSE = OPERATION.invert

  CHARACTER_PROPERTY = {
    0 => :map_x,
    1 => :map_y,
    2 => :direction,
    3 => :screen_x,
    4 => :screen_y,
    5 => :terrain_tag,
  }

  CHARACTER_PROPERTY_INVERSE = CHARACTER_PROPERTY.invert

  OTHER_PROPERTY = {
    0 => :map_id,
    1 => :party_members,
    2 => :gold,
    3 => :steps,
    4 => :play_time,
    5 => :timer,
    6 => :save_count,
  }

  OTHER_PROPERTY_INVERSE = OTHER_PROPERTY.invert

  def control_variables(variables, operation = "=", **args)
    if variables.is_a?(Range)
      parameters = [variables.begin, variables.end]
    else
      parameters = [variables, variables]
    end
    parameters.append OPERATION_INVERSE[operation]

    if args[:constant] != nil
      parameters.append 0, args[:constant]
    elsif args[:variable] != nil
      parameters.append 1, args[:variable]
    elsif args[:random] != nil
      parameters.append 2, args[:random].begin, args[:random].end
    elsif args[:item] != nil
      parameters.append 3, *args[:item]
    elsif args[:actor] != nil
      parameters.append 4, *args[:actor]
    elsif args[:enemy] != nil
      parameters.append 5, *args[:enemy]
    elsif args[:character] != nil
      parameters.append 6, args[:character], CHARACTER_PROPERTY_INVERSE[args[:property]]
    elsif args[:property] != nil
      parameters.append 7, OTHER_PROPERTY_INVERSE[args[:property]]
    end

    return command(122, *parameters)
  end

  def control_switches(switches, value)
    if switches.is_a?(Range)
      return command(121, switches.begin, switches.end, value)
    end
    return command(121, switches, switches, value)
  end

  def control_self_switch(switch, value)
    return command(123, switch, value)
  end

  GOLD_OPERATION = {
    0 => "+=",
    1 => "-=",
  }

  GOLD_OPERATION_INVERSE = GOLD_OPERATION.invert

  def change_gold(operation, **args)
    parameters = [GOLD_OPERATION_INVERSE[operation]]

    if args[:constant] != nil
      parameters.append 0, args[:constant]
    elsif args[:variable] != nil
      parameters.append 1, args[:variable]
    end

    return command(125, *parameters)
  end

  def scroll_map(direction:, distance:, speed:)
    return command(203, DIRECTION_INVERSE[direction], distance, speed)
  end

  def change_windowskin(name)
    return command(131, name)
  end

  def show_animation(character, animation)
    return command(207, character, animation)
  end

  def anim(id)
    return id
  end

  def recover_all(party)
    return command(314, party)
  end

  BLENDING = {
    0 => :normal,
    1 => :add,
    2 => :subtract,
  }

  BLENDING_INVERSE = BLENDING.invert

  def change_panorama(graphic:, hue: 0)
    return command(204, 0, graphic, hue)
  end

  def change_fog(graphic:, hue: 0, opacity: 0, blending:, zoom:, sx: 0, sy: 0)
    return command(204, 1, graphic, hue, opacity, BLENDING_INVERSE[blending], zoom, sx, sy)
  end

  def change_battleback(graphic:)
    return command(204, 2, graphic)
  end

  ORIGIN = {
    0 => :upper_left,
    1 => :center,
  }

  ORIGIN_INVERSE = ORIGIN.invert

  def show_picture(number:, graphic:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
    return command(231, number, graphic, ORIGIN_INVERSE[origin], 0, x, y, zoom_x, zoom_y, opacity, BLENDING_INVERSE[blending])
  end

  def show_picture_variables(number:, graphic:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
    return command(231, number, graphic, ORIGIN_INVERSE[origin], 1, x, y, zoom_x, zoom_y, opacity, BLENDING_INVERSE[blending])
  end

  def move_picture(number:, frames:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
    return command(232, number, frames, ORIGIN_INVERSE[origin], 0, x, y, zoom_x, zoom_y, opacity, BLENDING_INVERSE[blending])
  end

  def move_picture_variables(number:, frames:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
    return command(232, number, frames, ORIGIN_INVERSE[origin], 1, x, y, zoom_x, zoom_y, opacity, BLENDING_INVERSE[blending])
  end

  def rotate_picture(number:, speed:)
    return command(233, number, speed)
  end

  def erase_picture(number:)
    return command(235, number)
  end

  def evaluate(script)
    return eval(script)
  end
end
