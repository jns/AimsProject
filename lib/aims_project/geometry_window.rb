module AimsProject

  class GeometryWindow < Wx::Panel

    include Wx
    
    attr_accessor :update_unit_cell
    
    def initialize(app, parent)
      
      super(parent)
      @app = app
            
      # Initialize the selection of atoms
      @selection = {}
      
      # Tracks whether changes in inspector should update the unit cell
      @update_unit_cell = false
      
      # Get an inspector window to add into
      @inspector_window = @app.inspector.add_inspector_window
      
      # This is a model/controller for the inspector to pass to the crystal viewer
      @options = CrystalViewerOptions.new(@inspector_window)
      
      # Top level is a splitter
      topSplitterWindow = SplitterWindow.new(self)
      sizer = VBoxSizer.new
      sizer.add_item(topSplitterWindow, :proportion => 1, :flag => EXPAND)
      
      set_sizer(sizer)
      @console = GeometryConsole.new(self, topSplitterWindow)
      
      # The bottom is a vertical splitter
      geomWindowSplitter = SplitterWindow.new(topSplitterWindow)
      @geomEditor = GeometryEditor.new(self, geomWindowSplitter)
      @geomViewer = CrystalViewer.new(self, geomWindowSplitter, @options)
      
      geomWindowSplitter.split_vertically(@geomEditor, @geomViewer)
      
      # Add top and bottom sides together
      topSplitterWindow.split_horizontally(geomWindowSplitter, @console, -100)
      layout
      
      # Define events
      evt_list_item_selected(@console) {|evt|
        open_geometry_file(evt.get_item.get_data)
      }
      
      show_geometry(GeometryFile.new)
      
      
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
          show_geometry GeometryFile.new(File.new(file), @app.project.get_binding)
        else
          show_geometry GeometryFile.new(File.new(file))
        end


      rescue Exception => dang
        @app.error_dialog(dang)
      end
    end
    
    def image
      @geomViewer.image
    end
    
    # Get the currently displayed geometry
    def geometry
      @original_uc
    end
    
    # Display the given geometry
    def show_geometry(geometry)
      begin
        @original_uc = geometry
        @geomViewer.unit_cell = @original_uc
       rescue AimsProjectException => e
        @app.error_dialog(e)
      ensure
        @geomEditor.unit_cell = @original_uc
      end
      # @inspector.update(@geomViewer)
      # @geomViewer.draw_scene
    end
    
    def select_atom(atom)
      @selection[:atoms] = [atom]
      puts "Selection:" 
      puts @selection[:atoms].each{|a| puts a.format_geometry_in}
      @geomEditor.select_atom(atom)
    end
    
    def nudge_selected_atoms(x,y,z)
      if @selection[:atoms]
        @selection[:atoms].each{|a| a.displace!(x,y,z)}
      end
      @geomViewer.draw_scene
      @geomEditor.update
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