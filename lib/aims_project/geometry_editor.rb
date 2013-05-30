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
    
    basedir = File.dirname(__FILE__)
    arrow_icon = Image.new(File.join(basedir,"green_arrow.jpg"), BITMAP_TYPE_JPEG)
    @eval_button = BitmapButton.new(self, :bitmap => arrow_icon.rescale(16,15).convert_to_bitmap,:style=>BU_EXACTFIT, :name => "evaluate")
    
    @button_panel.add_item(@eval_button,3)
        
    sizer.add_item(@button_panel, :flag => EXPAND)
    sizer.add_item(@text_ctrl, :proportion => 1, :flag => EXPAND | ALL, :border => 5)

    set_auto_layout(true)
    set_sizer(sizer)
    
    evt_button(@eval_button) {|event|
        self.evaluate
    }

  end
  
  # Apply the edits to the geometry_file and evaluate
  def evaluate
    
    @unit_cell.raw_input = @text_ctrl.get_text
    begin
      @unit_cell.evaluate    
    rescue 
      # @button_pane.add_item(@clear_errors_button, 3)
      @app.display_exception($!)
    end
  end
  
  def unit_cell=(uc)
    @unit_cell = uc
    @text_ctrl.set_text(@unit_cell.input_geometry)      
  end
  
  def select_atom(atom)
    selectionStyle = Wx::RichTextAttr.new(Wx::BLACK, Wx::Colour.new("YELLOW"))
    
    pattern = atom.format_geometry_in
    puts "GeometryEditor.select_atom: pattern=#{pattern}"

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