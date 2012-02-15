
class Inspector < Wx::Frame

  include Wx

  class << self
    def control_value_accessor(*args)
      args.each do |cb|
        class_eval <<-EOS
        def #{cb.to_s}
          @#{cb.to_s}.get_value
        end
EOS
      end
    end
  end

  control_value_accessor :bond_length
  control_value_accessor :show_bonds, :show_lighting, :show_cell
  control_value_accessor :show_clip_planes, :show_xclip, :show_yclip, :show_zclip
  control_value_accessor :x_repeat, :y_repeat, :z_repeat
  control_value_accessor :correct
  
  attr_accessor :update_unit_cell
  
  def initialize(app, frame)
    
    super(frame, :style => (CLOSE_BOX | CAPTION | FRAME_FLOAT_ON_PARENT))

    @app = app
    
    sizer_top = BoxSizer.new(VERTICAL)

    sizer_top.add(view_options_panel(self), 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer_top)

    sizer_top.set_size_hints(self)
    sizer_top.fit(self)

    self.update_unit_cell = false

    self.evt_close {|event| self.hide }
  end
   
   # The view options
   def view_options_panel(parent)

     # Default padding around each element
     border = 5
     
     panel = Wx::Panel.new(parent)
     panel.sizer = Wx::VBoxSizer.new
      
     # Panel 1
     panel1 = Wx::Panel.new(panel, :style => Wx::SIMPLE_BORDER)
     panel1.sizer = Wx::VBoxSizer.new

     @show_bonds = Wx::CheckBox.new(panel1, :label => 'Show Bonds')
     panel1.sizer.add(@show_bonds, 0, Wx::ALL, border)
     
     @show_lighting = Wx::CheckBox.new(panel1, :label => 'Show Lighting')
     panel1.sizer.add(@show_lighting, 0, Wx::ALL, border)

     @show_cell = Wx::CheckBox.new(panel1, :label => "Show Unit Cell")
     panel1.sizer.add(@show_cell, 0, Wx::ALL,border)

     @correct = Wx::CheckBox.new(panel1, :label => "Correct Geometry")
     panel1.sizer.add(@correct, 0, Wx::ALL, border)

     sizer = GridSizer.new(2,1)
     sizer.add(StaticText.new(panel1, :label => "Bond Length"))
     @bond_length = SpinCtrl.new(panel1, :min => 1, :max => 100, :value => "4")
     sizer.add(@bond_length, 0, EXPAND)
     panel1.sizer.add(sizer)

     evt_checkbox(@show_bonds) {|evt| @app.update_viewer}
     evt_checkbox(@show_lighting) {|evt| @app.update_viewer}
     evt_checkbox(@show_cell) {|evt| @app.update_viewer}
     evt_checkbox(@correct) {|evt| 
        self.update_unit_cell = true
        @app.update_viewer
      }
     evt_spinctrl(@bond_length) {|evt| @app.update_viewer }
     
     # Panel 2 : Clip Planes
     panel2 = Wx::Panel.new(panel, :style => Wx::SIMPLE_BORDER)
     panel2.sizer = Wx::VBoxSizer.new
     panel2.sizer.add(StaticText.new(panel2, -1, "Clip Planes:", :style => ALIGN_LEFT))
     @show_xclip = Wx::CheckBox.new(panel2, :label => 'x')
     panel2.sizer.add(@show_xclip, 0, Wx::ALIGN_CENTER, border)
     @show_yclip = Wx::CheckBox.new(panel2, :label => 'y')
     panel2.sizer.add(@show_yclip, 0, Wx::ALIGN_CENTER, border)
     @show_zclip = Wx::CheckBox.new(panel2, :label => 'z')
     panel2.sizer.add(@show_zclip, 0, Wx::ALIGN_CENTER, border)
     

      evt_checkbox(@show_xclip) {|evt| @app.update_viewer}
      evt_checkbox(@show_yclip) {|evt| @app.update_viewer}
      evt_checkbox(@show_zclip) {|evt| @app.update_viewer}

      # Panel 3: Repeat
      panel3 = Wx::Panel.new(panel, :style => Wx::SIMPLE_BORDER)
      panel3.sizer = Wx::VBoxSizer.new
      panel3.sizer.add(StaticText.new(panel3, -1, "Repeat:", :style => ALIGN_LEFT), 0, EXPAND)

      panel3grid = GridSizer.new(3,2, border, border)
      
      @x_repeat = Wx::SpinCtrl.new(panel3, :value => "1", :min => 1, :max => 100, :initial => 1)
      @y_repeat = Wx::SpinCtrl.new(panel3, :value => "1", :min => 1, :max => 100, :initial => 1)
      @z_repeat = Wx::SpinCtrl.new(panel3, :value => "1", :min => 1, :max => 100, :initial => 1)

      evt_spinctrl(@x_repeat) {|evt| 
        self.update_unit_cell = true
        @app.update_viewer
      }
      evt_spinctrl(@y_repeat) {|evt| 
        self.update_unit_cell = true
        @app.update_viewer
      }
      evt_spinctrl(@z_repeat) {|evt| 
        self.update_unit_cell = true
        @app.update_viewer
      }

      panel3grid.add(StaticText.new(panel3, :label => "x", :style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@x_repeat,2)
      
      panel3grid.add(StaticText.new(panel3, :label => "y",:style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@y_repeat,2)
      
      panel3grid.add(StaticText.new(panel3, :label => "z",:style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@z_repeat,2)
      
      panel3.sizer.add(panel3grid, 0, EXPAND | ALIGN_CENTER)
      
      # Add sub-panels
      panel.sizer.add(panel1, 0, Wx::ALL)
      panel.sizer.add_spacer(5)
      panel.sizer.add(panel2, 0, Wx::EXPAND)
      panel.sizer.add_spacer(5)
      panel.sizer.add(panel3, 0, Wx::EXPAND)

     panel
   end
   
   # Called when a new file is loaded
   def update(viewer)
     @show_bonds.set_value(viewer.show_bonds)
     @show_lighting.set_value(viewer.lighting)
     @show_cell.set_value(viewer.show_supercell)
     @correct.set_value(false)
     @show_xclip.set_value(viewer.show_xclip)
     @show_yclip.set_value(viewer.show_yclip)
     @show_zclip.set_value(viewer.show_zclip)
     @bond_length.set_value(viewer.bond_length)
     @x_repeat.set_value(1)
     @y_repeat.set_value(1)
     @z_repeat.set_value(1)
   end
   
end
