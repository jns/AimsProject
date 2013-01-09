module AimsProject

class GeometryEditor < Wx::ScrolledWindow
  
  include Wx
  attr_accessor :app, :text_ctrl, :button_panel

  @atom_ranges = {}

  def initialize(app, window)
    
    super(window)

    @app = app
    
    sizer = BoxSizer.new(VERTICAL)

    @text_ctrl = StyledTextCtrl.new(self)
    # @text_ctrl.set_sel_background(true, Colour.new("wheat"))
    
    # Create the button panel (A toolbar for the top of this panel)
    @button_panel = HBoxSizer.new
    
    @toggle_source = CheckBox.new(self, ID_ANY, "Source")
    
    basedir = File.dirname(__FILE__)
    arrow_icon = Image.new(File.join(basedir,"green_arrow.jpg"), BITMAP_TYPE_JPEG)
    @eval_button = BitmapButton.new(self, :bitmap => arrow_icon.rescale(16,15).convert_to_bitmap,:style=>BU_EXACTFIT, :name => "evaluate")
    
    @button_panel.add_item(@toggle_source)
    @button_panel.add_stretch_spacer
    @button_panel.add_item(@eval_button)
    
    evt_checkbox(@toggle_source) {|evt|
      if @toggle_source.is_checked
        @text_ctrl.set_read_only(false)
        @text_ctrl.set_text(@unit_cell.raw_input)
      else
        @text_ctrl.set_read_only(false)
        @text_ctrl.set_text(@unit_cell.input_geometry)
        @text_ctrl.set_read_only(true)
      end
    }
    
    sizer.add(@button_panel)
    sizer.add(@text_ctrl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)

        
    evt_button(@eval_button) {|event|
      @unit_cell.raw_input = @text_ctrl.get_text
      @unit_cell.evaluate
    }

  end
  
  def unit_cell=(uc)
    @unit_cell = uc
    if @toggle_source.is_checked
      @text_ctrl.set_read_only(false)
      @text_ctrl.set_text(@unit_cell.raw_input)
      @text_ctrl.set_read_only(false)
      
    else
      @text_ctrl.set_read_only(false)
      @text_ctrl.set_text(@unit_cell.input_geometry)
      @text_ctrl.set_read_only(true)
      
    end
  end
  
  def select_atom(atom)
    selectionStyle = Wx::RichTextAttr.new(Wx::BLACK, Wx::Colour.new("YELLOW"))
    
    pattern = atom.format_geometry_in
    matchdata = self.text_ctrl.get_text.match(pattern)
    if matchdata
      lineStart = matchdata.begin(0)
      lineEnd = matchdata.end(0)
      # self.text_ctrl.set_style(lineStart...lineEnd, selectionStyle)
      self.text_ctrl.goto_pos(lineStart)
      self.text_ctrl.set_selection_start(lineStart)
      self.text_ctrl.set_selection_end(lineEnd)
    end
  end
  
  
  # Return the text contents of this control
  # after evaluating it with ERB
  def get_contents
    ERB.new(@text_ctrl.get_value).result
  end
end
end