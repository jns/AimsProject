
require 'erb'

class GeometryEditor < Wx::ScrolledWindow
  
  include Wx
  attr_accessor :app, :text_ctrl

  @atom_ranges = {}

  def initialize(app, window)
    
    super(window)

    @app = app
    
    sizer = BoxSizer.new(VERTICAL)

    @text_ctrl = RichTextCtrl.new(self)
    sizer.add(self.text_ctrl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)

        
    evt_text_enter(@text_ctrl) {|event|
      puts get_contents
    }

  end
  
  def unit_cell=(uc)
    @unit_cell = uc
    
    self.text_ctrl.set_value(uc.format_geometry_in)
  end
  
  def select_atom(atom)
    self.text_ctrl.set_style(start, stop, selectionStyle)
  end
  
  def get_contents
    ERB.new(@text_ctrl.get_value).result
  end
end