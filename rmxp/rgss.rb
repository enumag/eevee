#===============================================================================
# Filename:    rgss.rb
#
# Developer:   Raku (rakudayo@gmail.com)
#
# Description: This is the core file to include to enable loading and dumping
#    of RMXP's .rxdata files.
#===============================================================================

require_relative 'rgss_internal'
require_relative 'rgss_rpg'
require_relative 'rgss_mod'

# Initialize all classes to help Marshal.dump have consistent output.
RPG::Actor.new
RPG::Animation.new
RPG::Animation::Frame.new
RPG::Animation::Timing.new
RPG::Armor.new
RPG::AudioFile.new
RPG::Class.new
RPG::Class::Learning.new
RPG::CommonEvent.new
RPG::Enemy.new
RPG::Enemy::Action.new
RPG::Event.new(1, 1)
RPG::Event::Page.new
RPG::Event::Page::Condition.new
RPG::Event::Page::Graphic.new
RPG::EventCommand.new
RPG::Item.new
RPG::Map.new(1, 1)
RPG::MapInfo.new
RPG::MoveRoute.new
RPG::MoveCommand.new
RPG::Skill.new
RPG::State.new
RPG::System.new
RPG::System::Words.new
RPG::System::TestBattler.new
RPG::Tileset.new
RPG::Troop.new
RPG::Troop::Member.new
RPG::Troop::Page.new
RPG::Troop::Page::Condition.new
RPG::Weapon.new
Table.new(1)
Color.new(0, 0, 0)
Tone.new(0, 0, 0)
