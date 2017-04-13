# SimpleFSM - a DSL for finite state machines
#
# 
# This module provides a domain specific language (DSL) that 
# can be used to model a finite state machine (FSM) for any domain, 
# including complex communication applications 
# based on the SIP protocol.
#
# To utilize the DSL in a new class, the DSL module
# should be included into the class. The state machine the
# class is implementing is defined within the block of code
# after the fsm keyword.
#
# Authors:: Edin Pjanic (mailto:edin.pjanic@untz.com), Amer Hasanovic (mailto:amer.hasanovic@untz.com)
# License:: MIT License

module SimpleFSM
  VERSION = '0.2.1'

  def initialize
    self.current_state =  {}
    super
  end

  # start the machine
  def run 
    # p "run #{@@states}"
    # p "  fs: #{@@states.first}"
    self.current_state= @@states.first
    if current_state[:on]
      self.send(current_state[:on][:enter], nil) if current_state[:on].has_key?(:enter)
    end
  end

  # injecting the class methods for FSM definition
  def self.included klass
    klass.class_eval do
      @@states ||= []
      @@events ||= []
      @@transitions ||= {}
      @@current_state_setup = nil

      def self.fsm (&block)
        instance_eval(&block)

        #Events methods definition
        # - one method is defined for every event specified

        @@events.each do |ev|
          Kernel.send :define_method, ev do |*args|
            fsm_prepare_state args

            if args
              # If we have args here it must be an Array
              if args.class != Array
                return
              end
            else
              args = []
            end

            if current_state.class == Hash
              st = current_state[:state]
            else
              st = current_state
            end

            statetrans = @@transitions[st]
            uniquestates = []

            if statetrans
              # All transitions for this event in the current state
              trans = statetrans.select{|t| !t.select{|k, v| k==:event and v == ev}.empty?} 

              if trans and trans.size>0
                # Index of the first transition that is triggered
                index_triggered = trans.index do |v| 
                  # Guard specifiers:
                  # :guard      - all must be true
                  # :guard_not  - all must be false
                  # :guard_or   - at least one must be true
                  # All guard specified specifiers must evaluate to true
                  # in order for transition to be triggered.
                  guard_all = true
                  guards_and = []
                  guards_or = []
                  guards_not = []
                  if v.has_key?(:guard)
                    guards_and << v[:guard]
                    guards_and.flatten!
                  end
                  if v.has_key?(:guard_or)
                    guards_or << v[:guard_or]
                    guards_or.flatten!
                  end
                  if v.has_key?(:guard_not)
                    guards_not << v[:guard_not]
                    guards_not.flatten!
                  end

                  # TODO: think again about those guards
                  guard_all &&= guards_and.all?   {|g| self.send(g, args) } if guards_and.size > 0
                  guard_all &&= guards_or.any?    {|g| self.send(g, args) } if guards_or.size > 0
                  guard_all &&= !guards_not.any?  {|g| self.send(g, args) } if guards_not.size > 0
                  guard_all
                end 
                if index_triggered
                  trans_triggered = trans[index_triggered] 
                  new_state = trans_triggered[:new] if trans_triggered.has_key?(:new)

                  #START of :action keyword 
                  # Call procs for the current event
                  # :do keyword - is not prefered 
                  # because it confuses source code editors
                  action_keys = ['do'.to_sym, :action]

                  doprocs = []
                  action_keys.each do |key|
                    doprocs << trans_triggered[key] if trans_triggered.has_key?(key)
                  end
                  doprocs.flatten!

                  doprocs.each {|p| self.send(p, args)} if doprocs.size > 0
                  #END of :action keyword

                  do_transform new_state, args 
                end
              end
            end
            fsm_save_state args
          end
        end
      end


      ### FSM keywords: state, transitions_for ###

      # FSM state definition
      def self.state(sname, *data)
        state_data = {}
        symname = sname.to_sym
        state_data[:state] = symname

        if data
          state_data[:on] = data.first
        else
          state_data[:on] = {}
        end

        add_state_data symname, state_data
      end

      #FSM state transitions definition
      def self.transitions_for(sname, *trans, &block)
        return if !sname # return if sname is nil (no transition)
        sname = sname.to_sym
        @@transitions[sname] ||= [] 

        #add state in case it haven't been defined
        add_state_data sname 

        trans.each{ |t| check_transition sname, t }

        trans.each do |t|
          add_transition sname, t
          @@events << t[:event] if !@@events.any? { |e| t[:event] == e }
        end

        # if events block is given
        if block_given?
          @@current_state_setup = sname
          yield 
          @@current_state_setup = nil
        end

      end

      # the event keyword 
      def self.event ev, args, &block
        puts "! EVENT State is #{block.call}" if block_given?
        
        t = {:event => ev}.merge!(args)
        check_transition @@current_state_setup, t

        # TODO: try to simplify this!
        if !@@current_state_setup
          t
        else
          add_transition @@current_state_setup, t
        end
      end

      ## private class methods ######################

      # Check whether given transitin is valid
      def self.check_transition st, tran
        ev = tran[:event] if tran.is_a?(Hash) and tran.has_key?(:event) 
        ev ||= "unknown"

        if !tran or !tran.is_a?(Hash) or !tran.has_key?(:event) 
          raise "Error in transition specification for event '#{ev}' of state '#{st}'.\n " +
              "Transition MUST be a Hash and at least MUST contain keywords 'event' and 'new'.\n"  +
              "Transition data: #{tran}.\n"
              return
        end

      end

      # Add transition to state's transitions if it does not exist
      def self.add_transition st, t
          if !@@transitions[st].any? {|v| v == t}
            @@transitions[st] << t
            #add the state to @@states if it does not exist 
            add_state_data t[:new]
          end

          @@events << t[:event] if !@@events.any? { |e| t[:event] == e }
      end
      
      def self.add_state_data sname, data={:on=>nil}, overwrite=false
        return if !sname
        symname = sname.to_sym
        data.merge!({:state=>symname}) if !data.key?(symname)
        
        @@states.delete_if {|s| s[:state] == sname} if overwrite
        if !@@states.any?{|s| s[:state] == sname}
          @@states << data 
        end
      end


      private_class_method :fsm, :state, :transitions_for, :event
      private_class_method :add_state_data, :add_transition

    end
  end

  private

  # perform transition from current to the next state
  def do_transform sname, args
    # if new state is nil => don't change state
    return if !sname

    symname = sname.to_sym
    newstate = @@states.select{|a| a[:state] == symname}.first
    if !newstate
      raise "New state (#{sname}) is empty."
      return
    end

    onexit = current_state[:on][:exit] if current_state.has_key?(:on) and current_state[:on] and current_state[:on].has_key?(:exit)
    if newstate[:on]
      onenter = newstate[:on][:enter] if newstate[:on].has_key?(:enter)
    end

    self.send(onexit, args) if onexit
    self.current_state = newstate
    self.send(onenter, args) if onenter
  end

  def fsm_responds_to? ev
    if @@events
      return @@events.any?{|v| v == ev}
    else
      return false
    end
  end

  def fsm_state_responds_to? st, ev
    get_state_events(st).any?{|e| e == ev}
  end

  def get_state_events st
    ev = []
    tr = @@transitions[st[:state]]
    ev << tr.map{|tran| tran[:event]} if tr
    ev.uniq!
    ev
  end

  # PLEASE OVERRIDE  !
  # ################################################################### 
  # The following methods should be overriden according to the application.
  #
  # They are called when any event is fired in order 
  # to perform state loading/saving if the state is saved in
  # an external database or similar facility.
  #
  # state_full is a private method that returns a full state object
  # state is a public method that returns only the sate's name
  # fsm_prepare_state method is called before and
  # fsm_save_state method is called after
  # actual state transition and all consequent actions. 
  # get the current FSM state name
  
  def current_state
    # p "get current_state #{@state}"
    @state
  end

  def current_state= (st)
    # p "set current_state #{st}"
    @state = st
  end

  def state
    current_state[:state] #.to_sym
  end

  def fsm_prepare_state args
    current_state
  end

  def fsm_save_state args
    current_state
  end

  public :state
  private :current_state, :current_state=
  private :fsm_prepare_state, :fsm_save_state

end
