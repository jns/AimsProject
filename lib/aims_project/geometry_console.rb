
module AimsProject
  
  class CommandHistory

    def initialize
      @history= []
      @counter = 0
    end

    def save(cmd)
      @history.push(cmd)
      @counter = @history.size
    end
    
    def prev
      @counter = @history.size unless @counter
      if @counter > 0
        @counter = @counter - 1
      end
      @history[@counter]
    end
    
    def succ
      @counter = @history.size unless @counter
      if @counter < @history.size-1
        @counter = @counter + 1
      end
      @history[@counter]
    end
  end
  
  class GeometryConsole < Wx::ScrolledWindow
    
    include Wx
    include Aims
    
    def initialize(app, window)
      super(window)
      @app = app
      @text_ctrl = RichTextCtrl.new(self)
      @history = CommandHistory.new
      sizer = BoxSizer.new(VERTICAL)
      sizer.add_item(@text_ctrl, :proportion => 1, :flag => EXPAND | ALL, :border => 5)

      set_auto_layout(true)
      set_sizer(sizer)
      prompt
      
      @text_ctrl.evt_key_down do |evt|
        k = evt.get_key_code
        caret_pos = @text_ctrl.get_insertion_point
        
        case k
        when K_UP
          prev = @history.prev
          @text_ctrl.remove(@line_start, @text_ctrl.get_last_position)
          @text_ctrl.append_text(prev) if prev
        when K_DOWN
          succ = @history.succ
          @text_ctrl.remove(@line_start,@text_ctrl.get_last_position)
          @text_ctrl.append_text(succ) if succ
        when K_LEFT
          if caret_pos > @line_start
            @text_ctrl.set_insertion_point(caret_pos-1)
          end
        when K_RIGHT
          if caret_pos < @text_ctrl.get_last_position
            @text_ctrl.set_insertion_point(caret_pos+1)
          end          
        else
          if caret_pos < @line_start
            @text_ctrl.set_insertion_point(@line_start+1)
          end
          evt.skip
        end
      end
      
      @text_ctrl.evt_char do |evt|
        k = evt.get_key_code
        case k
        when K_RETURN
          cmd = @text_ctrl.get_range(@line_start, @text_ctrl.get_caret_position+1).strip
          @history.save(cmd)
          print "\n"
          # evaluate
          begin
            result = get_binding.eval(cmd)
            if result
              result_str = result.to_s
              print(result_str+"\n") 
            end
          rescue Exception => e
            print(e.message + "\n", Wx::RED)
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
      @line_start = @text_ctrl.get_caret_position + 1
      @text_ctrl.show_position(@line_start)
    end
    
    def print(str, color=Wx::BLACK)
      start = @text_ctrl.get_caret_position
      @text_ctrl.append_text(str)
      stop = @text_ctrl.get_caret_position
      @text_ctrl.set_style(start..stop, RichTextAttr.new(color))
    end
    
    def echo(str, color=Wx::BLACK)
      print(str+"\n", color)
      return nil
    end
    
    def ls(pattern = "*")
      match = Dir[pattern]
      print(match.join("\n") + "\n")
      return nil
    end
    
    def geometry
      @app.geometry
    end
    
    def set_geometry(geom)
      if geom.is_a? Aims::Geometry
        puts "All Good"
        @app.show_geometry(GeometryFile.new(geom))
      else
        echo("Not a valid geometry object")
      end
    end
    
  end
end