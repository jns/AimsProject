module AimsProject

class GeometryEditor < Wx::ScrolledWindow
  
  include Wx
  attr_accessor :app, :text_ctrl, :button_panel

  @atom_ranges = {}

  def initialize(app, window)
    
    super(window)

    @app = app
    
    sizer = BoxSizer.new(VERTICAL)

    @text_ctrl = RichTextCtrl.new(self)
    
    # Create the button panel (A toolbar for the top of this panel)
    @button_panel = HBoxSizer.new
    
    @toggle_button = Button.new(@button_panel, ID_ANY, "Code")
    button_panel_sizer.add_item(@toggle_button)
    evt_button(@toggle_button) {|evt|
      
    }
    
    sizer.add(@button_panel)
    sizer.add(self.text_ctrl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)

        
    evt_text_enter(@text_ctrl) {|event|
      @app.update
    }

  end
  
  def unit_cell=(uc)
    @unit_cell = uc
    
    self.text_ctrl.set_value(uc.format_geometry_in)
  end
  
  def select_atom(atom)
    selectionStyle = Wx::RichTextAttr.new(Wx::BLACK, Wx::Colour.new("YELLOW"))
    
    pattern = atom.format_geometry_in
    matchdata = self.text_ctrl.get_value.match(pattern)
    puts matchdata
    if matchdata
      lineStart = matchdata.begin(0)
      lineEnd = matchdata.end(0)
      # self.text_ctrl.set_style(lineStart...lineEnd, selectionStyle)
      self.text_ctrl.set_selection(lineStart, lineEnd)
      self.text_ctrl.set_caret_position(lineStart)
      self.text_ctrl.show_position(lineStart)
    end
  end
  
  
  # Return the text contents of this control
  # after evaluating it with ERB
  def get_contents
    ERB.new(@text_ctrl.get_value).result
  end
end
end