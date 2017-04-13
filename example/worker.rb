require 'rubygems'
require '../lib/simplefsm'

class Worker
  include SimpleFSM
  def initialize
    @counter = 5 
  end

  fsm do
    state :resting, 
      enter: :do_nothing
    state :working, 
      :enter => :check_in, 
      :exit => :check_out

    transitions_for :resting do 
      event :work, 
        guard: :check_counter,
        :new => :working 
      event :work, 
        action: :print_msg,
        new: nil 
    end

    transitions_for :working,
      event(:rest , 
      :new => :resting)

    # transitions_for :working do
    #   event :rest, :new => :resting
    # end
  end

  private
  def do_nothing args
    puts "I'm resting."
  end

  def print_msg args
    puts "I've already worked enough. In state #{state}."
  end

  def check_counter args
    @counter > 0
  end

  def check_in(args)
    puts "OK. I'm working now. (#{@counter})"
    puts "My tool: #{args.join(', ')}" if args.size > 0
    @counter -= 1
  end

  def check_out(args)
    puts "Hurray! End of my shift."
    puts " --------------------"
  end

end


joe = Worker.new
joe.run
joe.work :hammer
# some code
joe.rest 
joe.work :drill, :hammer
# some code
joe.rest
joe.work
joe.work
joe.rest
joe.work
joe.rest
joe.work
joe.rest
joe.work
joe.rest
joe.work
joe.rest
joe.work
