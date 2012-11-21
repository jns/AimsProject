module AimsProject

  class GeometryWindow < Wx::Panel

    include Wx
    
    def initialize(app, parent)
      
      super(parent)
      @app = app
      
      # Initialize the selection
      @selection = {}
      
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
    
  end
end