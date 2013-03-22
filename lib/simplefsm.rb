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
# License::   MIT License

module SimpleFSM
  VERSION = '0.2.0'

  def initialize
    @state ||=  {}
    super
  end

  # start the machine
  def run 
    @state = @@states.first
    if @state[:on]
      send(@state[:on][:enter], nil) if @state[:on].has_key?(:enter)
    end
  end

  # get the current FSM state name
  def state
    @state[:state] #.to_sym
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

            if @state.class == Hash
              st = @state[:state]
            else
              st = @state
            end

            statetrans = @@transitions[st]
            uniquestates = []

            if statetrans
              # All transitions for this event in the current state
              trans = statetrans.select{|t| !t.select{|k, v| k==:event and v == ev}.empty?} 

              if trans and trans.size>0
                # The first transition that is triggered
                index_triggered = trans.index do |v| 
                  # TODO: multiple guards (and, ...)
                  if v.has_key?(:guard)
                    send(v[:guard], args)
                  else
                    true
                  end
                end 
                trans_triggered = trans[index_triggered]
                new_state = trans_triggered[:new] if trans_triggered.has_key?(:new)

=begin
                trans_triggered.each do |a|
                  uniquestates << a[:new] if a.has_key?(:new)
                end
                uniquestates.uniq!
                numstates = uniquestates.size

                if numstates > 1
                  raise "Error in transition (event #{ev}, state #{st}): More than 1 (#{numstates}) new state (#{uniquestates.inspect})."
                  return
                elsif numstates < 1
                  return
                end
=end

                #START of :action keyword => call procs for event
                # :do keyword - is not prefered 
                # because it confuses source code editors
                action_keys = ['do'.to_sym, :action]

                doprocs = []
                action_keys.each do |key|
                  doprocs << trans_triggered[key] if trans_triggered.has_key?(key)
                end
                doprocs.flatten!
                #doprocs.uniq!

                doprocs.each {|p| send(p, args)} if doprocs.size > 0
                #END of :action keyword

                do_transform new_state, args 
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

        erroneous_trans = trans.select{|a| !a.has_key?(:event) or !a.has_key?(:new)}

        if !erroneous_trans.empty? 
          raise "Error in transitions for :#{sname}." +
              "Transition MUST contain keys :event and :new.\n" + 
              "In: " + erroneous_trans.inspect
              return
        end

        trans.each do |t|
          if t.class != Hash 
            raise "Error in transitions for :#{sname} in \'#{t.inspect}\'." +
              "Transition must be a Hash Array."
            return
          end

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
      def self.event ev, args
        if !args or !args.is_a?(Hash)
          raise "Error in event description for event: #{ev}." +
              "Transition MUST be a Hash and at least MUST contain key :new.\n"  
              return

        end
        if !args.has_key?(:new) 
          raise "Error in transitions for :#{sname}." +
              "Transition MUST contain keys :event and :new.\n" + 
              "In: " + erroneous_trans.inspect
              return
        end

        t = {:event => ev}.merge!(args)

        if !@@current_state_setup
          t
        else
          add_transition @@current_state_setup, t
        end
      end

      ## private class methods ######################

      # Add transition to state's transitions if it does not exist
      def self.add_transition st, t
          if !@@transitions[st].any? {|v| v == t}
            @@transitions[st] << t
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

    onexit = @state[:on][:exit] if @state.has_key?(:on) and @state[:on] and @state[:on].has_key?(:exit)
    if newstate[:on]
      onenter = newstate[:on][:enter] if newstate[:on].has_key?(:enter)
    end

    send(onexit, args) if onexit
    @state = newstate
    send(onenter, args) if onenter
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

  def get_state_events state
    ev = []
    tr = @@transitions[state[:state]]
    if tr 
      ts = tr.each{|t| ev << t[:event]}
      ev.uniq
    else
      []
    end
  end

  # The following methods should be overriden according to the application.
  #
  # They are called when any event is fired in order 
  # to perform state loading/saving if the state is saved in
  # an external database or similar facility.
  #
  # fsm_prepare_state method is called before and
  # fsm_save_state method is called after
  # actual state transition and all consequent actions. 
  def fsm_prepare_state args
    @state
  end

  def fsm_save_state args
    @state
  end
end
