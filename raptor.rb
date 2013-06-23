require 'pry'

class Raptor < RTanque::Bot::Brain
  NAME = 'CleverGirl'
  COLOR = :green

  GO_UP = RTanque::Heading.new_from_degrees(0)
  GO_RIGHT = RTanque::Heading.new_from_degrees(90)
  GO_DOWN = RTanque::Heading.new_from_degrees(180)
  GO_LEFT = RTanque::Heading.new_from_degrees(270)
  
  include RTanque::Bot::BrainHelper

  def initialize(*)
    super 
    @avoid_wall = 0
    @locked_heading = 0
    @direction = 90
    @dancing_adjustment = 0
    @firing_power_factor = 1

    @id = self.class.pack.count
    self.class.pack << self

    # hax
    @hax = false
    @match = ObjectSpace.each_object(RTanque::Match).first if @hax
  end

  def self.pack
    @pack ||= []
  end

  def tick!
    @prey = nil
    find_nearest_wall
    
    #@prey = find_prey
    if alpha?
      @prey = find_prey
    elsif alpha.nil?
      @prey = find_prey 
    else
      @prey = alpha.prey
    end
    
    if @prey
      strike_prey
    else
      stalk_prey
    end

    @prey = nil

    # hax
    whistle_for_help if alone?
  end

  def strike_prey
    if avoid_wall?
      move_away_from_wall
    else
      command.heading = do_le_tango
    end

    if alpha?
      command.radar_heading = @prey.heading
    else
      command.radar_heading = sensors.radar_heading - MAX_TURRET_ROTATION
    end

    command.turret_heading = predict_target_position(@prey)
    command.speed = MAX_BOT_SPEED

    if facing_prey?
      if raptor_in_the_way_of_prey? && sensors.gun_energy == RTanque::Bot::MAX_GUN_ENERGY
        abandon_hunt
      else
        command.fire(MAX_FIRE_POWER / @firing_power_factor) if prey_alive?
      end
    end
  end

  def stalk_prey
    if avoid_wall?
      move_away_from_wall
    end

    command.radar_heading = sensors.radar_heading - MAX_TURRET_ROTATION
    command.turret_heading = sensors.turret_heading - MAX_TURRET_ROTATION
    command.speed = MAX_BOT_SPEED
  end

  def find_prey
    sensors.radar.find { |reflection| reflection.type == :bot && reflection.name != NAME }
  end

  def alpha
    self.class.pack.find{ |raptor| raptor.stalking_prey? }
  end

  def prey
    @prey
  end

  def abandon_hunt
    @prey = nil
    command.radar_heading = sensors.radar_heading - direction
    command.turret_heading = sensors.turret_heading - direction
  end


  def do_le_tango
    @prey.heading + RTanque::Heading.new_from_degrees(direction)
  end


  def move_away_from_wall
    command.heading = GO_LEFT if @nearest_wall == :right
    command.heading = GO_RIGHT if @nearest_wall == :left
    command.heading = GO_DOWN if @nearest_wall == :top
    command.heading = GO_UP if @nearest_wall == :bottom
  end

  def find_nearest_wall
    @nearest_wall = :none
    @nearest_wall = :bottom if sensors.position.y < ( sensors.position.arena.height * 0.2 )
    @nearest_wall = :top if sensors.position.y > ( sensors.position.arena.height * 0.8 )
    @nearest_wall = :left if sensors.position.x < ( sensors.position.arena.width * 0.2 )
    @nearest_wall = :right if sensors.position.x > ( sensors.position.arena.width * 0.8 ) 
  end

  def direction
    at_tick_interval( rand(100)+100 ) { @direction *= -1 }
    @direction
  end

  def move_away_from_raptor
    command.heading = @nearby_raptor.heading - 180
  end

  def find_near_raptor
    @nearby_raptor = sensors.radar.find { |possible_raptor|
      raptor?(possible_raptor) && sensors.position.distance(possible_raptor.position) <= 200
    }
    @nearby_raptor
  end

  def predict_target_position(target)
    speed_modifier_based_on_distance = sensors.position.distance(target.position) / (22.5 * @firing_power_factor)
    expected_position = target.position.move(target.direction, target.speed * speed_modifier_based_on_distance)
    RTanque::Heading.new_between_points(sensors.position, expected_position)
  end

  def raptor_in_the_way_of_prey?
    sensors.radar.find { |possible_raptor| 
      raptor?(possible_raptor) && in_line_of_fire?(possible_raptor)
    }
  end

  def prey_alive?
    !find_prey.nil?
  end

  def facing_prey?
    in_line_of_fire? @prey
  end

  def stalking_prey?
    !@prey.nil?
  end

  def raptor?(raptor)
    raptor.type == :bot && raptor.name == NAME
  end

  def alpha?
    alpha == self unless alpha.nil?
  end

  def in_line_of_fire?(target)
    target_heading = predict_target_position(target)
    target_heading >= sensors.turret_heading - RTanque::Heading.new_from_degrees(15) || 
    target_heading <= sensors.turret_heading + RTanque::Heading.new_from_degrees(15)
  end

  def avoid_wall?
    @nearest_wall != :none
  end

  # hax
  def alone?
    @hax && !@match.bots.any?{ |bot| bot.brain.respond_to?(:clever_girl?) && (bot.brain != self) }
  end

  def whistle_for_help
    @match.add_bots(RTanque::Bot.new_random_location(@match.arena, self.class)) if @hax
  end

  def clever_girl?
    true
  end

  def print(something)
    puts "RAPTOR:#{@id} alpha:#{alpha?} --- #{something}"
  end
end