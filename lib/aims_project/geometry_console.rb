
module AimsProject
  class GeometryConsole < Wx::ScrolledWindow
    
    include Wx
    
    def initialize(app, window)
      super(window)
      @text_ctrl = RichTextCtrl.new(self)
      sizer = BoxSizer.new(VERTICAL)
      sizer.add_item(@text_ctrl, :proportion => 1, :flag => EXPAND | ALL, :border => 5)

      set_auto_layout(true)
      set_sizer(sizer)
      prompt
      
      @text_ctrl.evt_key_down do |evt|
        k = evt.get_key_code
        case k
        when K_UP
          echo("Key Up")
        when K_DOWN
          echo("Key Down")
        when K_LEFT
          caret_pos = @text_ctrl.get_insertion_point
          if caret_pos > @line_start
            @text_ctrl.set_insertion_point(caret_pos-1)
          end
        when K_RIGHT
          caret_pos = @text_ctrl.get_insertion_point
          if caret_pos < @text_ctrl.get_last_position
            @text_ctrl.set_insertion_point(caret_pos+1)
          end          
        else
          evt.skip
        end
      end
      
      @text_ctrl.evt_char do |evt|
        k = evt.get_key_code
        case k
        when K_RETURN
          cmd = @text_ctrl.get_range(@line_start, @text_ctrl.get_caret_position+1).strip
          print("\n")
          
          # evaluate
          begin
            result = get_binding.eval(cmd)
            print(result.to_s + "\n")
          rescue 
            print $!.to_s
            print "\n"
          end
          
          prompt
        when K_HOME # For some reason, ctrl-a maps to this
          @text_ctrl.set_insertion_point(@line_start)
        when K_HELP # For some reason, ctrl-e maps to this
          @text_ctrl.set_insertion_point_end
        else
          evt.skip()
        end
      end
      
    end
    
    def get_binding
      unless @binding
        @binding = binding()
      end
      @binding
    end
    
    def prompt
      @text_ctrl.append_text(">> ")
      @text_ctrl.move_end
      @line_start = @text_ctrl.get_caret_position
      @text_ctrl.show_position(@line_start)
    end
    
    def print(str)
      @text_ctrl.append_text(str)
    end
    
    def echo(str)
      @text_ctrl.append_text("\n" + str + "\n")
      prompt
    end
    
  end
end