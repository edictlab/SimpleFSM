[![Gem Version](https://badge.fury.io/rb/simplefsm.svg)](https://badge.fury.io/rb/simplefsm)

# SimpleFSM

A simple and lightweight domain specific language (DSL) for modeling finite state machines (FSM).

## Installation

Install SimpleFSM gem as any other Ruby gem:

      $ ruby gem install simplefsm

or, if you use JRuby:

      $ jruby -S gem install simplefsm

## Features and usage

You can read about SimpleFSM in our papers. PDF files are available at [this location](http://scholar.google.com/citations?user=7RoQiiQAAAAJ).

SimpleFSM DSL can be used to model an FSM for any domain. The main reason for SimpleFSM development is modeling SIP applications as FSMs. The DSL was developed in order to support the following requirements:

 - unlimited number of states can be used,
 - unlimited number of transitions can be specified,
 - state transition can be conditional, 
 - an action can be invoked on entering a state and/or exiting a state,
 - an action can be executed on an event, and
 - events can receive an arbitrary number of arguments which are sent to all related actions during the event processing.

FSM actions are modeled using Ruby methods. This makes the FSM model compact and clear. The entire DSL is implemented in a Ruby module called `SimpleFSM`.

To utilize the DSL in a new class, the DSL module
should be included into the class. The state machine,
that is implemented in the class, is defined within the
block of code after the `fsm` keyword.

## Example

Let's have a class Worker with two states as depicted in the following state diagram:

![Worker state diagram](http://edin.ictlab.com.ba/images/worker.png)

Code of the `Worker` class and its FSM definition could be:

```ruby
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
```

The class can be utilized as follows:

```ruby
joe = Worker.new
joe.run
joe.work :hammer               # =>  OK. I'm working now.
                               # =>  My tool: hammer
# some other code
joe.rest                       # => Hurray! End of my shift.
                               # =>  -------------------- 

joe.work :drill, :hammer       # =>  OK. I'm working now.
                               # =>  My tool: drill, hammer
# some other code
joe.rest                       # => Hurray! End of my shift.
                               # =>  -------------------- 
```

## Finite state machine definition and DSL keywords

### States

FSM states are defined using the `state` statement. The statement accepts optional
parameters, `:enter` and `:exit`. These parameters
can be used to specify actions that are executed when
entering or leaving the state that is being defined.

The initial state is the first state specified within the `fsm` block.

### Transitions

FSM state transitions are defined within the `transitions_for` statement. 
The arbitrary number of transitions for any state can be specified using the
`event` statement.

The FSM remains idle when a valid event is received which is not
specified in the `transition_for` statement related to
the current state.
The following is the full list of parameters that the `event` specification accepts inside the `transition_for` statement:

- `:new` specifies the destination state for the transition. The parameter is mandatory. If `:new` is `nil`, event is triggered but the transition is not performed
and the FSM remains in the same state.
- `:guard`, `:guard_or` and `:guard_not` specifies the Boolean function or functions for checking the transition’s condition. The parameters are optional. Two or more Boolean functions are specified in an Array. The event is triggered and transition is performed only if all specified guard specifiers evaluate to true.   
    - `:guard` evaluates to `true` only if all specified functions return `true`, example: `:guard => [:is_REGISTER?, :another_condition]`
    - `:guard_or` evaluates to `true` if at least one of these functions return `true`, example: `:guard_or => [:condition1?, :condition2, :condition3]`
    - `:guard_not` evaluates to true if all of these functions return `false`, example: `:guard_not => :valid_user?`

- `:action` specifies the method or methods (specified in an array) to be called when the event is fired. This parameter is optional. If `:guard` is specified, then the `:action` method is called only if the `:guard` method returns `true`. It is possibe to use the keyword `:do` for this specification, but it is not prefered because it confuses source code editors.

Two aditional versions of `transitions_for` specification are supported, both without using the `do-end` block. 
The transitions from the `Worker` class can be written in the following forms:

```ruby
    transitions_for :resting,
      event(:work, :new => :working)
    transitions_for :working,
      event(:rest, :new => :resting)
```

 or

```ruby
    transitions_for :resting,
      {event => :work, :new => :working}
    transitions_for :working,
      {event => :rest, :new => :resting}
```

States specified as `:new` in any `transitions_for` statement are created if they are not explicitly defined using the state statement.
However, if `:exit` and `:enter` actions for the state are required the `state` statement must be used. States specified in the fsm block will become available in
the objects that are instances of the class with the `fsm` specification. For every event in the `fsm` block, an object will get a method with the same name, which
can be used to generate the event.

Only one transition in `transitions_for` specifications for the current state can be performed.
When an event is invoked, the transitions for the current state are evaluated in the order they are specified inside the `fsm` specification. 
The first transition that is triggered on the event is then performed.

### Starting the machine

  The machine within the object is started calling the `run` instance method. After that the machine performs transitions according to the `fsm` specification.

## Remarks

### Injected methods and variables 

When `SimpleFSM` module is included into a Ruby class the following class, methods and variables are injected into it (into the destination class). 
They are necessary for a proper functioning of this DSL.

#### A class 
Objects that are instances of `TransitionFactory` class are used for making transitions specified in `event` clauses within `transitions_for` code blocks.
User code should not utilize this class.

#### Class and instance methods
The following methods should not be overriden:
- public instance method: `run`
- private instance methods: `do_transform`, `fsm_responds_to?`, `fsm_state_responds_to?`, `get_state_events` 
- private class methods: `fsm`, `state`, `transitions_for`, `event`, `add_state_data`, `add_transition`

The following methods should be overriden in case the state is saved in the external database or similar facility:
- public instance method: `state`
- private instance methods: `current_state`, `set_current_state`

#### Variables

- instance variable: `@state` 
- class variables: `@@states`, `@@events`, `@@transitions`

Variable `@state` keeps the current state of the machine and is referenced only within methods `state`, `current_state` and `set_current_state`. 
If the current state of the machine is kept in an external database then the aforementioned methods should be overriden and variable `@state` is probably unnecessary.




