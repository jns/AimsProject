module AimsProject
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
  control_value_accessor :transparent_bg
  
  attr_accessor :update_unit_cell
  
  def initialize(app, frame)
    
    super(frame, :style => (SYSTEM_MENU | CAPTION | FRAME_FLOAT_ON_PARENT))
    enable_close_button
    
    @app = app
    
    # Array to track the inspector windows being shown
    @windows = []
    
    self.sizer = BoxSizer.new(VERTICAL)
    set_auto_layout(true)
    self.sizer.set_size_hints(self)
    self.sizer.fit(self)

    self.update_unit_cell = false
    self.evt_close {|event| self.hide }
  end
   
   # Create a window to show in the inspector. Default is to not show this window.
   # call show_inspector_window() to show it
   # options are Wx:Sizer options
   # return the window so that caller can add controls to it
   def add_inspector_window(options = {})
     window = Panel.new(self)
     @windows << window
     self.sizer.add_item(window, options)
     self.sizer.show(window, false)
     return window
   end
   
   # Show the inspector window
   def show_inspector_window(window)
     @windows.each {|w|
         self.sizer.show(w, w == window)
      }
      self.sizer.fit(self)
   end
   
   # The view options
   def view_options_panel(parent)

     # Default padding around each element
     border = 5
     
     panel = Wx::VBoxSizer.new
     parent.sizer = panel
      
     # Panel 1
     panel1 =  Wx::VBoxSizer.new

     @show_bonds = Wx::CheckBox.new(parent, :label => 'Show Bonds')
     panel1.add_item(@show_bonds, :flag => ALL,:border => border)
     
     @show_lighting = Wx::CheckBox.new(parent, :label => 'Show Lighting')
     panel1.add_item(@show_lighting, :flag => ALL, :border => border)

     @show_cell = Wx::CheckBox.new(parent, :label => "Show Unit Cell")
     panel1.add_item(@show_cell, :flag => ALL, :border => border)

     @correct = Wx::CheckBox.new(parent, :label => "Correct Geometry")
     panel1.add_item(@correct, :flag => ALL, :border => border)

     @transparent_bg = Wx::CheckBox.new(parent, :label => "Transparent BG")
     panel1.add_item(@transparent_bg, :flag => ALL, :border => border)

     gsizer = GridSizer.new(2,1)
     gsizer.add(StaticText.new(parent, :label => "Bond Length"))
     @bond_length = SpinCtrl.new(parent, :min => 1, :max => 100, :value => "4")
     gsizer.add_item(@bond_length, :flag => EXPAND)
     panel1.add_item(gsizer)

     evt_checkbox(@show_bonds) {|evt| @app.update_viewer}
     evt_checkbox(@show_lighting) {|evt| @app.update_viewer}
     evt_checkbox(@show_cell) {|evt| @app.update_viewer}
     evt_checkbox(@transparent_bg) {|evt| @app.update_viewer}
     evt_checkbox(@correct) {|evt| 
        self.update_unit_cell = true
        @app.update_viewer
      }
     evt_spinctrl(@bond_length) {|evt| @app.update_viewer }
     
     # Panel 2 : Clip Planes
     panel2 =  Wx::VBoxSizer.new
     panel2.add_item(StaticText.new(parent, -1, "Clip Planes:", :style => ALIGN_LEFT))
     @show_xclip = Wx::CheckBox.new(parent, :label => 'x')
     panel2.add_item(@show_xclip, 0, Wx::ALIGN_CENTER, border)
     @show_yclip = Wx::CheckBox.new(parent, :label => 'y')
     panel2.add_item(@show_yclip, 0, Wx::ALIGN_CENTER, border)
     @show_zclip = Wx::CheckBox.new(parent, :label => 'z')
     panel2.add_item(@show_zclip, 0, Wx::ALIGN_CENTER, border)
     

      evt_checkbox(@show_xclip) {|evt| @app.update_viewer}
      evt_checkbox(@show_yclip) {|evt| @app.update_viewer}
      evt_checkbox(@show_zclip) {|evt| @app.update_viewer}

      # Panel 3: Repeat
      panel3 = Wx::VBoxSizer.new
      panel3.add_item(StaticText.new(parent, -1, "Repeat:", :style => ALIGN_LEFT), 0, EXPAND)

      panel3grid = GridSizer.new(3,2, border, border)
      
      @x_repeat = Wx::SpinCtrl.new(parent, :value => "1", :min => 1, :max => 100, :initial => 1)
      @y_repeat = Wx::SpinCtrl.new(parent, :value => "1", :min => 1, :max => 100, :initial => 1)
      @z_repeat = Wx::SpinCtrl.new(parent, :value => "1", :min => 1, :max => 100, :initial => 1)

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

      panel3grid.add(StaticText.new(parent, :label => "x", :style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@x_repeat,2)
      
      panel3grid.add(StaticText.new(parent, :label => "y",:style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@y_repeat,2)
      
      panel3grid.add(StaticText.new(parent, :label => "z",:style => ALIGN_RIGHT),1, EXPAND)
      panel3grid.add(@z_repeat,2)
      
      panel3.add(panel3grid, 0, EXPAND | ALIGN_CENTER)
      
      # Add sub-panels
      panel.add(panel1, 0, Wx::ALL)
      panel.add_spacer(5)
      panel.add(panel2, 0, Wx::EXPAND)
      panel.add_spacer(5)
      panel.add(panel3, 0, Wx::EXPAND)

     
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
end
