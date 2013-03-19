require 'rubygems'
require 'simplefsm'

class Worker
  include SimpleFSM

  fsm do
    state :resting
    state :working, 
      :enter => :check_in, 
      :exit => :check_out

    transitions_for :resting do
      event :work, :new => :working
    end

    transitions_for :working do
      event :rest, :new => :resting
    end
  end

  private
  def check_in(args)
    puts "OK. I'm working now."
    puts "My tool: #{args.join(', ')}" if args.size > 0
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
puts joe.state
