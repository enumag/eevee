module RPGDSLFactory

  def self.parse(params = [], factory = nil, &block)
    factory = RPGFactory.new if factory.nil?
    list = params.clone
    list.push *Contexts::ExecutionContext.compile(factory, &block)
    return list
  end

  module Contexts
    module DSLLike
      def self.included(othermod)
        othermod.define_singleton_method(:create) { |*args, &block|
          inst = self.new(*args)
          inst.instance_exec(&block)
          next inst
        }

        othermod.define_singleton_method(:compile) { |*args, &block|
          inst = self.new(*args)
          inst.instance_exec(&block)
          next inst.compile
        }
      end
    end

    class ExecutionContext
      include DSLLike

      def initialize(factory)
        @insns = []
        @factory = factory
      end

      def anim(id)
        return id
      end

      ### ========================
      ###         COMMANDS
      ### ========================

      def script(script) = @insns.push(@factory.script(script))
      def text(*parts) = @insns.push(@factory.text(*parts))
      def comment(*parts) = @insns.push(@factory.comment(*parts))

      def input_number(variable, digits:) = @insns.push(@factory.input_number(unwrap(variable), digits: digits))
      def change_text_options(position, window) = @insns.push(@factory.change_text_options(position, window))
      def button_input_processing(variable) = @insns.push(@factory.button_input_processing(unwrap(variable)))
      def wait(time) = @insns.push(@factory.wait(time))
      def wait_for_move_completion() = @insns.push(@factory.wait_completion)
      def exit_event_processing() = @insns.push(@factory.exit_event_processing)
      def erase_event() = @insns.push(@factory.erase_event)
      def call_common_event(id) = @insns.push(@factory.call_common_event(id))
      def label(name) = @insns.push(@factory.label(name))
      def jump_label(name) = @insns.push(@factory.jump_label(name))

      def battle_bgm(audio) = @insns.push(@factory.battle_bgm(audio))
      def battle_me(audio) = @insns.push(@factory.battle_me(audio))
      def play_bgm(audio) = @insns.push(@factory.play_bgm(audio))
      def play_bgs(audio) = @insns.push(@factory.play_bgs(audio))
      def play_me(audio) = @insns.push(@factory.play_me(audio))
      def play_se(audio) = @insns.push(@factory.play_se(audio))

      def stop_se() = @insns.push(@factory.stop_se)
      def fade_out_bgm(seconds:) = @insns.push(@factory.fade_out_bgm(seconds: seconds))
      def fade_out_bgs(seconds:) = @insns.push(@factory.fade_out_bgs(seconds: seconds))
      def change_tone(red:, green:, blue:, gray: 0, frames:) = @insns.push(@factory.change_tone(red: red, green: green, blue: blue, gray: gray, frames: frames))
      def change_fog_tone(red:, green:, blue:, gray: 0, frames:) = @insns.push(@factory.change_fog_tone(red: red, green: green, blue: blue, gray: gray, frames: frames))
      def change_fog_opacity(opacity:, frames:) = @insns.push(@factory.change_fog_opacity(opacity: opacity, frames: frames))
      def change_picture_tone(number:, red:, green:, blue:, gray: 0, frames:) = @insns.push(@factory.change_picture_tone(number: number, red: red, green: green, blue: blue, gray: gray, frames: frames))
      def screen_flash(red:, green:, blue:, alpha: 0, frames:) = @insns.push(@factory.screen_flash(red: red, green: green, blue: blue, alpha: alpha, frames: frames))
      def screen_shake(power:, speed:, frames:) = @insns.push(@factory.screen_shake(power: power, speed: speed, frames: frames))

      def transfer_player(map:, x:, y:, direction:, fading:)
        if any_variable?(map, x, y)
          @insns.push(@factory.transfer_player_variables(map: map, x: unwrap(x), y: unwrap(y), direction: direction, fading: fading))
        else
          @insns.push(@factory.transfer_player(map: map, x: x, y: unwrap(y), direction: direction, fading: fading))
        end
      end

      def set_event_location(character, x:, y:, direction:)
        if any_variable?(x, y)
          @insns.push(@factory.event_location(unwrap(character), x: unwrap(x), y: unwrap(y), direction: direction))
        else
          @insns.push(@factory.event_location_variables(unwrap(character), x: x, y: y, direction: direction))
        end
      end

      def swap_event_locations(character, target:, direction:) = @insns.push(@factory.event_location_swap(character, target: target, direction: direction))

      def branch(on, *args, &block)
        params = {}
        if on.is_a?(RPGDSLFactory::Wrappers::Switch)
          params[:switch] = unwrap(on)
          params[:value] = args.empty? ? :ON : args[0]
        elsif on.is_a?(RPGDSLFactory::Wrappers::SelfSwitch)
          params[:self_switch] = unwrap(on)
          params[:value] = args.empty? ? :ON : args[0]
        elsif on.is_a?(RPGDSLFactory::Wrappers::Variable)
          operation = args[0]
          state = args[1]
          params[:variable] = unwrap(on)
          params[:operation] = operation
          if any_variable?(state)
            params[:other_variable] = unwrap(state)
          else
            params[:constant] = state
          end
        elsif on.is_a?(RPGDSLFactory::Wrappers::TimerValue)
          params[:timer] = args[1]
          params[:operation] = args[0]
        elsif on.is_a?(RPGDSLFactory::Wrappers::GoldValue)
          params[:gold] = args[1]
          params[:operation] = args[0]
        elsif on.is_a?(String)
          params[:script] = on
        elsif on.is_a?(RPGDSLFactory::Wrappers::EventProxy)
          params[:character] = unwrap(on)
          params[:facing] = args[0]
        elsif on.is_a?(Numeric) || on.is_a?(Symbol)
          params[:button] = on
        elsif on.is_a?(Hash)
          params[:type] = on[:type]
          params[:parameters] = on[:parameters]
        end

        context = BranchExecutionContext.create(@factory, params, &block)
        @insns.push(context)
        return context
      end

      def battle(*parameters, &block)
        @insns.push(BattleContext.compile(@factory, parameters, &block))
      end

      def loop(&block)
        @insns.push(@factory.repeat(commands: ExecutionContext.compile(@factory, &block)))
      end

      def break_loop() = @insns.push(@factory.break_loop)

      def show_choices(text=nil, &block)
        @insns.push(@factory.text(text)) if text
        @insns.push(ChoiceContext.create(@factory, &block))
      end

      def set_move_route(character, &block)
        route, repeat, skippable = MoveRouteContext.compile(@factory, &block)
        @insns.push(@factory.move_route(unwrap(character), *route, repeat: repeat, skippable: skippable))
        return RPGDSLFactory::Wrappers::MoveRouteWaiter.new(self)
      end

      def control_variables(variables, operator = "=", **args) = @insns.push(@factory.control_variables(unwrap(variables), operator, **args))
      def control_switches(switches, value) = @insns.push(@factory.control_switches(unwrap(switches), value))
      def control_self_switch(chr, value) = @insns.push(@factory.control_self_switch(chr, value))

      def change_gold(operator, value)
        if any_variable?(value)
          @insns.push(@factory.change_gold(operator, variable: unwrap(value)))
        else
          if operator == "+=" && value.negative?
            operator = "-="
            value = value.abs
          end
          @insns.push(@factory.change_gold(operator, constant: value))
        end
      end

      def scroll_map(direction:, distance:, speed:) = @insns.push(@factory.scroll_map(direction: direction, distance: distance, speed: speed))
      def change_windowskin(name) = @insns.push(@factory.change_windowskin(name))
      def show_animation(character, animation) = @insns.push(@factory.show_animation(unwrap(character), animation))
      def recover_all(party = 0) = @insns.push(@factory.recover_all(party))
      def change_panorama(graphic:, hue: 0) = @insns.push(@factory.change_panorama(graphic: graphic, hue: hue))
      def change_fog(graphic:, hue: 0, opacity: 0, blending:, zoom:, sx: 0, sy: 0) = @insns.push(@factory.change_fog(graphic: graphic, hue: hue, opacity: opacity, blending: blending, zoom: zoom, sx: sx, sy: sy))
      def change_battleback(graphic:) = @insns.push(@factory.change_battleback(graphic: graphic))

      def show_picture(number:, graphic:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
        if any_variable?(x, y)
          @insns.push(@factory.show_picture_variables(number: number, graphic: graphic, origin: origin, x: unwrap(x), y: unwrap(y), zoom_x: zoom_x, zoom_y: zoom_y, opacity: opacity, blending: blending))
        else
          @insns.push(@factory.show_picture(number: number, graphic: graphic, origin: origin, x: x, y: y, zoom_x: zoom_x, zoom_y: zoom_y, opacity: opacity, blending: blending))
        end
      end

      def move_picture(number:, frames:, origin:, x: 0, y: 0, zoom_x: 100, zoom_y: 100, opacity: 255, blending:)
        if any_variable?(x, y)
          @insns.push(@factory.move_picture_variables(number: number, frames: frames, origin: origin, x: unwrap(x), y: unwrap(y), zoom_x: zoom_x, zoom_y: zoom_y, opacity: opacity, blending: blending))
        else
          @insns.push(@factory.move_picture(number: number, frames: frames, origin: origin, x: x, y: y, zoom_x: zoom_x, zoom_y: zoom_y, opacity: opacity, blending: blending))
        end
      end

      def rotate_picture(number:, speed:) = @insns.push(@factory.rotate_picture(number: number, speed: speed))
      def erase_picture(number:) = @insns.push(@factory.erase_picture(number: number))
      def weather_effect(weather:, power:, frames:) = @insns.push(@factory.weather_effect(weather: weather, power: power, frames: frames))
      def change_transparent_flag(flag) = @insns.push(@factory.change_transparent_flag(flag))
      def change_save_access(flag) = @insns.push(@factory.change_save_access(flag))
      def change_menu_access(flag) = @insns.push(@factory.change_menu_access(flag))
      def change_encounters(flag) = @insns.push(@factory.change_encounter(flag))
      def prepare_for_transition() = @insns.push(@factory.prepare_transition)
      def execute_transition(graphic) = @insns.push(@factory.execute_transition(graphic))
      def call_menu_screen() = @insns.push(@factory.call_menu_screen)
      def call_save_screen() = @insns.push(@factory.call_save_screen)
      def game_over() = @insns.push(@factory.game_over)
      def title_screen() = @insns.push(@factory.title_screen)
      def memorize_bgm_bgs() = @insns.push(@factory.memorize_bgm_bgs)
      def restore_bgm_bgs() = @insns.push(@factory.restore_bgm_bgs)
      def start_timer(seconds) = @insns.push(@factory.start_timer(seconds))
      def stop_timer() = @insns.push(@factory.stop_timer)

      def command(code, *parameters) = @insns.push(@factory.command(code, *parameters))

      ### ============================
      ###         END COMMANDS
      ### ============================

      def compile
        list = []
        for insn in @insns
          if insn.is_a?(RPG::EventCommand)
            list << insn
          elsif insn.respond_to?("compile")
            list.push *insn.compile
          end
        end

        return list
      end
    end

    class BranchExecutionContext < ExecutionContext
      include DSLLike

      def initialize(factory, parameters)
        super(factory)
        @parameters = parameters
      end

      ### ========================
      ###         COMMANDS
      ### ========================
      def else(&block) = @else = ExecutionContext.create(@factory, &block)
      ### ============================
      ###         END COMMANDS
      ### ============================
      def compile
        list = []
        for insn in @insns
          if insn.is_a?(RPG::EventCommand)
            list << insn
          elsif insn.respond_to?("compile")
            list.push *insn.compile
          end
        end

        @parameters[:then] = list

        if @else
          @parameters[:else] = @else.compile
        end

        return @factory.condition(**@parameters)
      end
    end

    class ChoiceContext
      include DSLLike

      def initialize(factory)
        @choices = []
        @contexts = []
        @cancel = nil
        @cancelcode = nil
        @factory = factory
      end

      ### ========================
      ###         COMMANDS
      ### ========================

      def choice(name, &block)
        @choices << name
        @contexts << ExecutionContext.create(@factory, &block)
      end

      def when_cancel(value = nil, &block)
        if value
          @cancel = value
        elsif block_given?
          @cancelcode = ExecutionContext.create(@factory, &block)
        end
      end

      def default_choice(name, &block)
        choice(name, &block)
        when_cancel(name)
      end

      ### ============================
      ###         END COMMANDS
      ### ============================

      def compile
        params = {
          choices: @choices,
          cancellation: 0
        }

        params[:choice1] = @contexts[0].compile if @contexts.size >= 1
        params[:choice2] = @contexts[1].compile if @contexts.size >= 2
        params[:choice3] = @contexts[2].compile if @contexts.size >= 3
        params[:choice4] = @contexts[3].compile if @contexts.size >= 4

        if @cancelcode
          params[:cancellation] = 5 # Branch
          params[:cancel] = @cancelcode.compile
        elsif @cancel.is_a?(Numeric)
          params[:cancellation] = @cancel
        elsif @cancel.is_a?(String)
          params[:cancellation] = (@choices.index(@cancel) || -1) + 1
        end

        return @factory.show_choices(**params)
      end
    end

    class BattleContext
      include DSLLike

      def initialize(factory, parameters)
        @win = nil
        @escape = nil
        @lose = nil
        @factory = factory
        @params = parameters
      end

      ### ========================
      ###         COMMANDS
      ### ========================

      def when_win(&block)
        @win = ExecutionContext.create(@factory, &block)
      end

      def when_escape(&block)
        @escape = ExecutionContext.create(@factory, &block)
      end

      def when_lose(&block)
        @lose = ExecutionContext.create(@factory, &block)
      end

      ### ============================
      ###         END COMMANDS
      ### ============================

      def compile
        win = @win ? @win.compile : []
        escape = @escape ? @escape.compile : nil
        lose = @lose ? @lose.compile : []
        return @factory.battle(parameters: @params, win: win, escape: escape, lose: lose)
      end
    end

    class MoveRouteContext
      include DSLLike

      def initialize(factory)
        @repeat = false
        @skippable = false
        @insns = []
        @factory = factory
      end

      ### ========================
      ###         COMMANDS
      ### ========================

      def mark_as_repeat() = @repeat = true

      def mark_as_skippable() = @skippable = true


      def move_down() = @insns.push(@factory.move_down)
      def move_left() = @insns.push(@factory.move_left)
      def move_right() = @insns.push(@factory.move_right)
      def move_up() = @insns.push(@factory.move_up)
      def move_lower_left() = @insns.push(@factory.move_lower_left)
      def move_lower_right() = @insns.push(@factory.move_lower_right)
      def move_upper_left() = @insns.push(@factory.move_upper_left)
      def move_upper_right() = @insns.push(@factory.move_upper_right)
      def move_random() = @insns.push(@factory.move_random)
      def move_toward_player() = @insns.push(@factory.move_toward_player)
      def move_away_from_player() = @insns.push(@factory.move_away_from_player)
      def move_forward() = @insns.push(@factory.move_forward)
      def move_backward() = @insns.push(@factory.move_backward)
      def jump_to(x:, y:) = @insns.push(@factory.jump(x: x, y: y))
      def wait(frames) = @insns.push(@factory.route_wait(frames))
      def face_down() = @insns.push(@factory.turn_down)
      def face_left() = @insns.push(@factory.turn_left)
      def face_right() = @insns.push(@factory.turn_right)
      def face_up() = @insns.push(@factory.turn_up)
      def turn_right() = @insns.push(@factory.turn_right_90)
      def turn_left() = @insns.push(@factory.turn_left_90)
      def turn_around() = @insns.push(@factory.turn_180)
      def turn_randomly() = @insns.push(@factory.turn_right_or_left_90)
      def face_randomly() = @insns.push(@factory.turn_random)
      def face_toward_player() = @insns.push(@factory.turn_toward_player)
      def face_away_from_player() = @insns.push(@factory.turn_away_from_player)

      def control_switches(switch, value) = set_switch(switch, state: value)

      def set_switch(switch, state:) = @insns.push(state == :ON ? @factory.switch_on(unwrap(switch)) : @factory.switch_off(unwrap(switch)))
      def change_speed(speed) = @insns.push(@factory.change_speed(speed))
      def change_frequency(freq) = @insns.push(@factory.change_frequency(freq))

      def animate_walking(state=true) = @insns.push(state ? @factory.walk_anime_on : @factory.walk_anime_off)
      def animate_steps(state=true) = @insns.push(state ? @factory.step_anime_on : @factory.step_anime_off)
      def lock_direction(state=true) = @insns.push(state ? @factory.direction_fix_on : @factory.direction_fix_off)
      def set_intangible(state=true) = @insns.push(state ? @factory.through_on : @factory.through_off)
      def set_always_foreground(state=true) = @insns.push(state ? @factory.always_on_top_on : @factory.always_on_top_off)
      def set_character(name: "", hue: 0, direction: :down, pattern: 0) = @insns.push(@factory.change_graphic(name: name, hue: hue, direction: direction, pattern: pattern))
      def remove_graphic = set_character
      def set_opacity(opacity) = @insns.push(@factory.change_opacity(opacity))
      def set_blend_type(blend) = @insns.push(@factory.change_blending(blend))

      def play_se(audio) = @insns.push(@factory.route_play_se(audio))
      def script(script) = @insns.push(@factory.route_script(script))

      def command(code, *parameters) = @insns.push(@factory.move(code, *parameters))

      ### ============================
      ###         END COMMANDS
      ### ============================

      def compile
        list = []
        for insn in @insns
          if insn.is_a?(RPG::MoveCommand)
            list.push(insn)
          elsif insn.respond_to?("compile")
            list.push(insn.compile)
          end
        end

        return list, @repeat, @skippable
      end
    end

    ### ==========================================
    ###         Syntactic Sugar goes below
    ### ==========================================

    module DSLLike
      def unwrap(holder)
        if holder.is_a?(Range)
          return unwrap(holder.begin)..unwrap(holder.end)
        end
        return holder.event if holder.is_a?(RPGDSLFactory::Wrappers::EventProxy)
        return holder.key if holder.is_a?(RPGDSLFactory::Wrappers::HolderProxy)
        return holder
      end

      def any_variable?(*holders)
        return holders.any? { |it| it.is_a?(RPGDSLFactory::Wrappers::HolderProxy) }
      end

      # following are legacy holdovers
      def s(id) = @factory.s(id)
      def v(id) = @factory.v(id)
      def anim(id) = @factory.anim(id)
      def character(id) = @factory.character(id)

      def audio(name: "", volume: 100, pitch: 100) = RPG::AudioFile.new(name, volume, pitch)

      def variables() = RPGDSLFactory::Wrappers::Variables.new(self)
      def switches() = RPGDSLFactory::Wrappers::Switches.new(self)
      def events() = RPGDSLFactory::Wrappers::EventSourceProxy.new(self)
      def self_switch() = RPGDSLFactory::Wrappers::OwnSelfSwitches.new(self)

      def items() = RPGDSLFactory::Wrappers::Items.new(self)
      def actors() = RPGDSLFactory::Wrappers::Actors.new(self)
      def enemies() = RPGDSLFactory::Wrappers::Enemies.new(self)

      def map_id() = RPGDSLFactory::Wrappers::GlobalValue.new(:map_id)
      def party_members() = RPGDSLFactory::Wrappers::GlobalValue.new(:party_members)
      def steps() = RPGDSLFactory::Wrappers::GlobalValue.new(:steps)
      def play_time() = RPGDSLFactory::Wrappers::GlobalValue.new(:play_time)
      def timer() = RPGDSLFactory::Wrappers::TimerValue.new(:timer)
      def save_count() = RPGDSLFactory::Wrappers::GlobalValue.new(:save_count)

      def player() = RPGDSLFactory::Wrappers::PlayerEventProxy.new(self)
      def this() = RPGDSLFactory::Wrappers::OwnEventProxy.new(self)
    end
  end

  module Wrappers

    ### Proxies for passing around variables

    class HolderProxy
      attr_reader :key

      def initialize(key)
        @key = key
      end

      # Enables creating ranges with holder proxies
      def <=>(other)
        other = other.key if other.is_a?(RPGDSLFactory::Wrappers::HolderProxy)
        return key <=> other
      end
    end

    class EventHolderProxy < HolderProxy
      attr_reader :event

      def initialize(event, key)
        @event = event
        @key = key
      end
    end

    ### End proxies

    class Variables
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        if idx.is_a?(Range)
          return Variable.new(idx.begin)..Variable.new(idx.end)
        end
        return Variable.new(idx)
      end

      def operate(idx, operator, value)
        if value.is_a?(Variable)
          dsl.control_variables(idx, operator, variable: value.key)
        elsif value.is_a?(Range)
          dsl.control_variables(idx, operator, random: value)
        elsif value.is_a?(ItemValue)
          dsl.control_variables(idx, operator, item: value.key)
        elsif value.is_a?(ActorValue)
          dsl.control_variables(idx, operator, actor: value.key)
        elsif value.is_a?(EnemyValue)
          dsl.control_variables(idx, operator, enemy: value.key)
        elsif value.is_a?(CharacterValue)
          dsl.control_variables(idx, operator, character: value.event, property: value.key)
        elsif value.is_a?(GlobalValue)
          dsl.control_variables(idx, operator, property: value.key)
        elsif value.is_a?(Numeric)
          dsl.control_variables(idx, operator, constant: value)
        end
      end

      def []=(idx, value)
        operator = "="
        operator, value = value if value.is_a?(Array)
        operate(idx, operator, value)
      end
    end

    class Switches
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        if idx.is_a?(Range)
          return Switch.new(idx.begin)..Switch.new(idx.end)
        end
        return Switch.new(idx)
      end

      def []=(idx, value)
        dsl.control_switches(idx, value)
      end
    end

    class SelfSwitches
      attr_reader :event
      attr_reader :dsl

      def initialize(event, dsl)
        @event = event
        @dsl = dsl
      end

      def [](idx)
        return SelfSwitch.new(event, idx)
      end
    end

    class OwnSelfSwitches < SelfSwitches
      def initialize(dsl)
        super(:This, dsl)
      end

      def []=(idx, value)
        dsl.control_self_switch(idx, value)
      end
    end

    class Items
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        return ItemValue.new(idx)
      end
    end

    class Actors
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        return ActorValue.new(idx)
      end
    end

    class Enemies
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        return EnemyValue.new(idx)
      end
    end

    class SelfSwitches
      attr_reader :event
      attr_reader :dsl

      def initialize(event, dsl)
        @event = event
        @dsl = dsl
      end

      def [](idx)
        return SelfSwitch.new(event, idx)
      end
    end

    class EventProxy
      attr_reader :event
      attr_reader :dsl

      def initialize(dsl, event)
        @dsl = dsl
        @event = event
      end

      def self_switch() = SelfSwitches.new(event, dsl)

      def x() = CharacterValue.new(event, :map_x)
      def y() = CharacterValue.new(event, :map_y)
      def direction() = CharacterValue.new(event, :direction)
      def screen_x() = CharacterValue.new(event, :screen_x)
      def screen_y() = CharacterValue.new(event, :screen_y)
      def terrain_tag() = CharacterValue.new(event, :terrain_tag)

      def set_event_location(x:, y:, direction:) = dsl.set_event_location(self, x: x, y: y, direction: direction)
      def swap_event_locations(target:, direction:) = dsl.swap_event_locations(self, target: target, direction: direction)
      def set_move_route(&block) = dsl.set_move_route(self, &block)
      def show_animation(animation) = dsl.show_animation(self, animation)
    end

    class OwnEventProxy < EventProxy
      def initialize(dsl)
        super(dsl, 0)
      end

      def self_switch() = OwnSelfSwitches.new(dsl)
    end

    class PlayerEventProxy < EventProxy
      def initialize(dsl)
        super(dsl, -1)
      end

      def self_switch() = OwnSelfSwitches.new(dsl)

      def gold() = GoldValue.new(:gold)

      def gold=(operation)
        operator, value = operation
        dsl.change_gold(operator, value)
      end
    end

    class EventSourceProxy
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def [](idx)
        return EventProxy.new(dsl, @dsl.character(idx))
      end
    end

    class MoveRouteWaiter
      attr_reader :dsl

      def initialize(dsl)
        @dsl = dsl
      end

      def wait
        dsl.wait_for_move_completion
      end
    end

    class ItemValue < HolderProxy; end
    class ActorValue < HolderProxy; end
    class EnemyValue < HolderProxy; end

    class CharacterValue < EventHolderProxy; end
    class Variable < HolderProxy
      def +(value) = ["+=", value]
      def -(value) = ["-=", value]
      def *(value) = ["*=", value]
      def /(value) = ["/=", value]
      def %(value) = ["%=", value]
    end
    class Switch < HolderProxy; end
    class SelfSwitch < EventHolderProxy; end

    class GlobalValue < HolderProxy; end
    class TimerValue < GlobalValue; end
    class GoldValue < GlobalValue
      def +(value) = ["+=", value]
      def -(value) = ["-=", value]
    end
  end
end
