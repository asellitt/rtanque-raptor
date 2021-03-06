require 'pry'
class Trex < RTanque::Bot::Brain
  NAME = 'Trex'
  COLOR = :red

  GO_UP = RTanque::Heading.new_from_degrees(0)
  GO_RIGHT = RTanque::Heading.new_from_degrees(90)
  GO_DOWN = RTanque::Heading.new_from_degrees(180)
  GO_LEFT = RTanque::Heading.new_from_degrees(270)
  
  include RTanque::Bot::BrainHelper

  def initialize(whatever)
    @avoid_wall = 0
    @locked_heading = 0
    @direction = 90
    @dancing_adjustment = 0

    # hax
    @hax = false
    @match = ObjectSpace.each_object(RTanque::Match).first if @hax

    super(whatever)
  end

  def tick!
    @desired_heading ||= nil
    find_nearest_wall

    @prey = find_prey
    if @prey
      strike_prey
      @desired_heading = nil
    else
      stalk_prey
    end

    # hax
    whistle_for_help if alone?
  end

  def strike_prey
    if avoid_wall?
      move_away_from_wall
    else
      heading = do_le_tango
      command.heading = @prey.distance > 250 ? heading : -heading
    end

    command.radar_heading = @prey.heading
    command.turret_heading = predict_prey_position
    command.speed = MAX_BOT_SPEED

    command.fire(MAX_FIRE_POWER) unless raptor_in_the_way_of_prey?
  end

  def predict_prey_position
    speed_modifier_based_on_distance = sensors.position.distance(@prey.position) / 22.5
    expected_position = @prey.position.move(@prey.direction, @prey.speed * speed_modifier_based_on_distance)
    RTanque::Heading.new_between_points(sensors.position, expected_position)
  end

  def stalk_prey
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

  def find_prey
    sensors.radar.find { |reflection| reflection.type == :bot && reflection.name != NAME }
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

  def raptor_in_the_way_of_prey?
    sensors.radar.find { |possible_raptor| 
      raptor?(possible_raptor) && in_line_of_fire?(possible_raptor)
    }
  end

  def raptor?(raptor)
    raptor.type == :bot && raptor.name == NAME
  end

  def in_line_of_fire?(prey)
    prey.heading >= sensors.turret_heading - 15 || prey.heading <= sensors.turret_heading + 15
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
end