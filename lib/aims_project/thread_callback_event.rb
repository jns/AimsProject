module AimsProject
  class ThreadCallbackEvent < Wx::CommandEvent
    
    @@event_type_id = 0
    
    def ThreadCallbackEvent.set_event_type(id)
      @@event_type_id = id
    end
    
    def ThreadCallbackEvent.event_type
      @@event_type_id
    end
    
    def initialize
      super(@@event_type_id)
    end
    
    end
end