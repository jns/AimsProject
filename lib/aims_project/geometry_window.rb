module AimsProject

  class GeometryWindow < Wx::Panel

    include Wx
    
    attr_accessor :update_unit_cell
    
    def initialize(app, parent)
      
      super(parent)
      @app = app
      
      # Initialize the selection
      @selection = {}
      
      # Tracks whether changes in inspector should update the unit cell
      @update_unit_cell = false
      
      # Top level is a splitter
      topSplitterWindow = SplitterWindow.new(self)
      sizer = VBoxSizer.new
      sizer.add_item(topSplitterWindow, :proportion => 1, :flag => EXPAND)
      
      set_sizer(sizer)
      
      # The top is a list control
      @geomList = ListCtrl.new(topSplitterWindow)
      app.project.geometries.each{|geom|
        li = ListItem.new
        li.set_text(geom)
        li.set_data(geom)
        @geomList.insert_item(li)
      }
      
      # The bottom is a vertical splitter
      geomWindowSplitter = SplitterWindow.new(topSplitterWindow)
      @geomEditor = GeometryEditor.new(self, geomWindowSplitter)
      @geomViewer = CrystalViewer.new(self, geomWindowSplitter)
      
      geomWindowSplitter.split_vertically(@geomEditor, @geomViewer)
      
      # Add top and bottom sides together
      topSplitterWindow.split_horizontally(@geomList, geomWindowSplitter, 100)
      layout
      
      # Define events
      evt_list_item_selected(@geomList) {|evt|
        open_geometry_file(evt.get_item.get_data)
      }
      
      # make the inspector window
      make_inspector
      
    end
    
    def make_inspector
      
      # Get an inspector window to add into
      @inspector_window = @app.inspector.add_inspector_window

      # Default padding around each element
      border = 5

      @inspector_window.sizer = VBoxSizer.new

      # Panel 1
      panel1 =  Wx::VBoxSizer.new
      
      @show_bonds = Wx::CheckBox.new(@inspector_window, :label => 'Show Bonds')
      panel1.add_item(@show_bonds, :flag => ALL,:border => border)
      
      @show_lighting = Wx::CheckBox.new(@inspector_window, :label => 'Show Lighting')
      panel1.add_item(@show_lighting, :flag => ALL, :border => border)
      
      @show_cell = Wx::CheckBox.new(@inspector_window, :label => "Show Unit Cell")
      panel1.add_item(@show_cell, :flag => ALL, :border => border)
      
      @correct = Wx::CheckBox.new(@inspector_window, :label => "Correct Geometry")
      panel1.add_item(@correct, :flag => ALL, :border => border)
      
      @transparent_bg = Wx::CheckBox.new(@inspector_window, :label => "Transparent BG")
      panel1.add_item(@transparent_bg, :flag => ALL, :border => border)
      
      gsizer = GridSizer.new(2,1)
      gsizer.add(StaticText.new(@inspector_window, :label => "Bond Length"))
      @bond_length = SpinCtrl.new(@inspector_window, :min => 1, :max => 100, :value => "4")
      gsizer.add_item(@bond_length, :flag => EXPAND)
      panel1.add_item(gsizer)
      
      
      # Panel 2 : Clip Planes
      panel2 =  Wx::VBoxSizer.new
      panel2.add_item(StaticText.new(@inspector_window, -1, "Clip Planes:", :style => ALIGN_LEFT))
      @show_xclip = Wx::CheckBox.new(@inspector_window, :label => 'x')
      panel2.add_item(@show_xclip, :flag => Wx::ALIGN_CENTER, :border => border)
      @show_yclip = Wx::CheckBox.new(@inspector_window, :label => 'y')
      panel2.add_item(@show_yclip, :flag => Wx::ALIGN_CENTER, :border => border)
      @show_zclip = Wx::CheckBox.new(@inspector_window, :label => 'z')
      panel2.add_item(@show_zclip, :flag => Wx::ALIGN_CENTER, :border => border)
      
      
      
       # Panel 3: Repeat
       panel3 = Wx::VBoxSizer.new
       panel3.add_item(StaticText.new(@inspector_window, -1, "Repeat:", :style => ALIGN_LEFT), :flag => EXPAND)
      
       panel3grid = GridSizer.new(3,2, border, border)
      
       @x_repeat = Wx::SpinCtrl.new(@inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)
       @y_repeat = Wx::SpinCtrl.new(@inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)
       @z_repeat = Wx::SpinCtrl.new(@inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)
            
       panel3grid.add(StaticText.new(@inspector_window, :label => "x", :style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(@x_repeat,2)
      
       panel3grid.add(StaticText.new(@inspector_window, :label => "y",:style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(@y_repeat,2)
      
       panel3grid.add(StaticText.new(@inspector_window, :label => "z",:style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(@z_repeat,2)
      
       panel3.add_item(panel3grid, :flag => EXPAND | ALIGN_CENTER)

       # Event Handling
       @inspector_window.evt_checkbox(@show_bonds) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@show_lighting) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@show_cell) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@transparent_bg) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@correct) {|evt| 
          self.update_unit_cell = true
          update_viewer
        }
       @inspector_window.evt_spinctrl(@bond_length) {|evt| update_viewer }
       @inspector_window.evt_checkbox(@show_xclip) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@show_yclip) {|evt| update_viewer}
       @inspector_window.evt_checkbox(@show_zclip) {|evt| update_viewer}

       @inspector_window.evt_spinctrl(@x_repeat) {|evt| 
         self.update_unit_cell = true
         update_viewer
       }
       @inspector_window.evt_spinctrl(@y_repeat) {|evt| 
         self.update_unit_cell = true
         update_viewer
       }
       @inspector_window.evt_spinctrl(@z_repeat) {|evt| 
         self.update_unit_cell = true
         update_viewer
       }


       # Add sub-panels
       @inspector_window.sizer.add_item(panel1, :flag => EXPAND, :proportion => 1)
       @inspector_window.sizer.add_spacer(5)
       @inspector_window.sizer.add_item(panel2, :flag => EXPAND, :proportion => 1)
       @inspector_window.sizer.add_spacer(5)
       @inspector_window.sizer.add_item(panel3, :flag => EXPAND, :proportion => 1)
    end
    
    def show_inspector
      @app.inspector.show_inspector_window(@inspector_window)
    end
    
    # Display a file dialog and attempt to open and display the file
    def open_geometry_file(file = nil)
      begin
        unless file
          fd = FileDialog.new(@app.frame, :message => "Open", :style => FD_OPEN, :default_dir => @working_dir)
          if ID_OK == fd.show_modal
            file = fd.get_path
            @working_dir = fd.get_directory
          else
            return
          end
        end
        @app.set_status "Opening #{file}"

        if (@app.project)
          erb = ERB.new(File.read(file))
          show_geometry Aims::GeometryParser.parse_string(erb.result(@app.project.get_binding))
        else
          show_geometry Aims::GeometryParser.parse(file)
        end


      rescue Exception => dang
        @app.error_dialog(dang)
      end
    end
    
    # Display the given geometry
    def show_geometry(geometry)
      @original_uc = geometry
      @geomViewer.unit_cell = @original_uc
      @geomEditor.unit_cell = @original_uc
      # @inspector.update(@geomViewer)
      @geomViewer.draw_scene
    end
    
    def select_atom(atom)
      @selection[:atoms] = [atom]
      @geomEditor.select_atom(atom)
    end
    
    def nudge_selected_atoms(x,y,z)
      if @selection[:atoms]
        @selection[:atoms].each{|a| a.displace!(x,y,z)}
      end
      @geomViewer.draw_scene
    end
    
    # Apply UI settings to viewer and re-render
    def update_viewer
      
      puts "GeometryWindow.update_viewer"

      if @original_uc and self.update_unit_cell
        if @correct.get_value
          # @geomViewer.unit_cell = @original_uc.correct
          new_geom = @original_uc.repeat(@x_repeat.get_value, @y_repeat.get_value, @z_repeat.get_value).correct
        else
          # @geomViewer.unit_cell = @original_uc
          new_geom = @original_uc.repeat(@x_repeat.get_value, @y_repeat.get_value, @z_repeat.get_value)
        end
        @geomViewer.unit_cell = new_geom
        @geomEditor.unit_cell = new_geom
        self.update_unit_cell = false
      end

      # @geomViewer.repeat = [@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat]
      @geomViewer.show_bonds = @show_bonds.get_value
      @geomViewer.bond_length = @bond_length.get_value
      @geomViewer.lighting = @show_lighting.get_value
      @geomViewer.show_supercell = @show_cell.get_value
      @geomViewer.show_xclip = @show_xclip.get_value
      @geomViewer.show_yclip = @show_yclip.get_value
      @geomViewer.show_zclip = @show_zclip.get_value
      @geomViewer.background.alpha = ((@transparent_bg.get_value) ? 0 : 1)
      @geomViewer.draw_scene
    end
    
  end
end