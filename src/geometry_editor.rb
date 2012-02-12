
class GeometryEditor < Wx::ScrolledWindow
  
  include Wx
  attr_accessor :app, :text_ctrl

  def initialize(app, window)
    
    super(window)

    @app = app
    
    sizer_top = BoxSizer.new(VERTICAL)

    self.text_ctrl = RichTextCtrl.new(self)
    sizer_top.add(self.text_ctrl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer_top)

    sizer_top.set_size_hints(self)
    # sizer_top.fit(self)

    self.evt_close {|event| self.hide }
  end
  
  def unit_cell=(uc)
    @unit_cell = uc
    self.text_ctrl.set_value(uc.format_geometry_in)
  end
  
  def select_atom(atom)
    self.text_ctrl.set_style(start, stop, selectionStyle)
  end
end