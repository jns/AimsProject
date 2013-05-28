
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
      
      def @text_ctrl.on_char(evt)
        k = evt.key_code
        mflag = evt.modifiers

        case k
        when K_RETURN
          if evt.inputmod_down
            # multi-line command uses meta-down-arrow for newline
            self.write_text("\n")
          else
            @history << self.value
            run self.value
            self.clear
          end
          return
        when (evt.inputmod_down and K_UP)
          if hist=history.prev
            self.value = hist
            self.set_insertion_point_end
            return
          end
        when (evt.inputmod_down and K_DOWN)
          if hist=history.next
            self.value = hist
            self.set_insertion_point_end
            return
          else
            self.clear
          end
        end
        evt.skip()
      end
      
    end
    
    def prompt
      @text_ctrl.append_text(">> ")
      @text_ctrl.move_end
      @insertion_point = @text_ctrl.get_caret_position
      @text_ctrl.show_position(@insertion_point)
    end
    
    
    def echo(str)
      @text_ctrl.append_text("\n" + str + "\n")
      prompt
    end
    
  end
end