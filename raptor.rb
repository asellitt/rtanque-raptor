require 'pry'
class Raptor < RTanque::Bot::Brain
  NAME = 'CleverGirl'
  COLOR = :green
  include RTanque::Bot::BrainHelper

  TURRET_FIRE_RANGE = RTanque::Heading::ONE_DEGREE * 5.0

  def initialize(whatever)
    @avoid_wall = 0
    @locked_heading = 0
    @direction = 60

    @hax = false
    @match = ObjectSpace.each_object(RTanque::Match).first if @hax
    super(whatever)
  end

  def tick!
    @desired_heading ||= nil
    set_nearest_wall

    if (lock = self.get_radar_lock)
      self.destroy_lock(lock)
      @desired_heading = nil
    else
      self.seek_lock
    end

    whistle_for_help if alone?
  end

  def destroy_lock(reflection)
    if avoid_wall?
      move_away_from_wall
    else
      heading = reflection.heading - RTanque::Heading.new_from_degrees(direction)
      command.heading = reflection.distance > 250 ? heading : -heading
    end

    command.radar_heading = reflection.heading
    command.turret_heading = predict_target_position(reflection)
    command.speed = MAX_BOT_SPEED
    if (reflection.heading.delta(sensors.turret_heading)).abs < TURRET_FIRE_RANGE
      command.fire(reflection.distance > 200 ? MAX_FIRE_POWER : MIN_FIRE_POWER)
    end
  end

  def predict_target_position(target)
    speed_modifier_based_on_distance = sensors.position.distance(target.position) / 10
    expected_target_position = target.position.move(target.direction, target.speed * speed_modifier_based_on_distance)
    RTanque::Heading.new_between_points(sensors.position, expected_target_position)
  end

  def seek_lock
    if avoid_wall?
      move_away_from_wall
    end
    command.radar_heading = sensors.radar_heading + MAX_RADAR_ROTATION
    command.speed = MAX_BOT_SPEED
    if @desired_heading
      command.heading = @desired_heading
      command.turret_heading = @desired_heading
    end
  end

  def get_radar_lock
    sensors.radar.find { |reflection| reflection.type == :bot && reflection.name != NAME }
  end

  def direction
    #pry binding if sensors.radar.any? { |a| a.type == :shell && a.name != NAME }
    if sensors.ticks % (rand(100)+100) == 0
      @direction *= -1
    end

    @direction
  end

  GO_UP = RTanque::Heading.new_from_degrees(0)
  GO_UP_AND_RIGHT = RTanque::Heading.new_from_degrees(45)
  GO_RIGHT = RTanque::Heading.new_from_degrees(90)
  GO_DOWN_AND_RIGHT = RTanque::Heading.new_from_degrees(135)
  GO_DOWN = RTanque::Heading.new_from_degrees(180)
  GO_DOWN_AND_LEFT = RTanque::Heading.new_from_degrees(225)
  GO_LEFT = RTanque::Heading.new_from_degrees(270)
  GO_UP_AND_LEFT = RTanque::Heading.new_from_degrees(315)

  def avoid_wall?
    @nearest_wall != :none
  end

  def move_away_from_wall
    command.heading = GO_LEFT if @nearest_wall == :right
    command.heading = GO_RIGHT if @nearest_wall == :left
    command.heading = GO_DOWN if @nearest_wall == :top
    command.heading = GO_UP if @nearest_wall == :bottom
  end

  def do_le_tango
  end

  # lets pretend we're in point.rb

  def set_nearest_wall
    @nearest_wall = :none
    @nearest_wall = :bottom if sensors.position.y < ( sensors.position.arena.height * 0.2 )
    @nearest_wall = :top if sensors.position.y > ( sensors.position.arena.height * 0.8 )
    @nearest_wall = :left if sensors.position.x < ( sensors.position.arena.width * 0.2 )
    @nearest_wall = :right if sensors.position.x > ( sensors.position.arena.width * 0.8 ) 
  end

  def alone?
    #@
    @hax && !@match.bots.any?{ |bot| bot.brain.respond_to?(:clever_girl?) && (bot.brain != self) }
  end

  def whistle_for_help
    @match.add_bots(RTanque::Bot.new_random_location(@match.arena, self.class)) if @hax
  end

  def clever_girl?
    true
  end
end