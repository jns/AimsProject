
module AimsProject
class AppController < Wx::App
  
    include Wx
  
    ID_ROTATE = 100
    ID_PAN = 101
    ID_ZOOM = 102
    ID_SAVE_IMAGE = 103  
    ID_MOVE_CLIP_PLANE = 104

    ID_INSPECTOR = 201

    ID_DELETE_ATOM = 301
    
    @frame = nil
    @menubar = nil
    @toolbar = nil
    @geomViewer = nil
    @geomEditor = nil
    @inspector = nil
    @statusbar = nil
    @projectTree = nil
    @calcTree = nil

    # The original Unit Cell
    @original_uc = nil
    
    # The project
    attr_accessor :project
    
    # Used to synchronize directory in open/save dialogs
    attr_accessor :working_dir
    
    
   # Build the application
   def on_init
     
        self.app_name = "AimsViewer"
        # Create the frame, toolbar and menubar and define event handlers
        size = [1000,700]
        @frame = Frame.new(nil, -1, "AimsViewer", DEFAULT_POSITION, size)
        @statusbar = @frame.create_status_bar

        # Initialize the selection
        @selection = {}
        
        # Create the notebook
        @notebook = Notebook.new(@frame)
        
        # Create the geometry window
        # The base window is a horizontal splitter
        # Left side is a list control
        geomWindow = SplitterWindow.new(@notebook)
        @geomList = ListCtrl.new(geomWindow)
        project.geometries.each{|geom|
          li = ListItem.new
          li.set_text(geom)
          li.set_data(geom)
          @geomList.insert_item(li)
        }
        evt_list_item_selected(@geomList) {|evt|
          open_file(evt.get_item.get_data)
        }

        # Right side is a vertical splitter
        geomWindowSplitter = SplitterWindow.new(geomWindow)
        @geomEditor = GeometryEditor.new(self, geomWindowSplitter)
        @geomViewer = CrystalViewer.new(self, geomWindowSplitter)
        
        geomWindowSplitter.split_vertically(@geomEditor, @geomViewer)
        
        # Add Left and right sides together
        geomWindow.split_horizontally(@geomList, geomWindowSplitter, 100)
        
        # Create the control window
        # The base window is a horizontal splitter
        # Left side is a list of control files
        # right side is a Rich Text Control
        controlWindow = SplitterWindow.new(@notebook)
        @controlList = ListCtrl.new(controlWindow);
        @controlEditor = RichTextCtrl.new(controlWindow)
        controlWindow.split_horizontally(@controlList, @controlEditor)
        
        # Create the calculations window
        # Similar to the geometryWindow
        # Left side is a list control
        # Right side is a crystal viewer
        calcWindow = SplitterWindow.new(@notebook)
        calcWindowSplitter = SplitterWindow.new(calcWindow)
        @calcList = ListCtrl.new(calcWindow)
        
        @calcTree = CalculationTree.new(self, calcWindowSplitter)
        @calcViewer = CrystalViewer.new(self, calcWindowSplitter)
        calcWindowSplitter.split_vertically(@calcTree, @calcViewer)
        calcWindow.split_horizontally(@calcList, calcWindowSplitter, 100)
        # Populate the calculations list
        project.calculations.each{|calc|
          li = ListItem.new
          li.set_text(calc.name)
          li.set_data(calc)
          @calcList.insert_item(li)
        }
        evt_list_item_selected(@calcList) {|evt|
          show_calculation(evt.get_item.get_data)
        }
        
        # Add windows to the notebook
        @notebook.add_page(geomWindow, 'Geometry')
        @notebook.add_page(controlWindow, "Control")
        @notebook.add_page(calcWindow, "Calculations")
        
        # Create the split view        
        # hsplitter = SplitterWindow.new(@frame)
        # splitter = SplitterWindow.new(hsplitter)
                
        
        # panel = Panel.new(splitter)
        # panelSizer = BoxSizer.new(VERTICAL)
        # panel.set_sizer(panelSizer)
        # panelSizer.add(@calcTree, 1, EXPAND)
        # panelSizer.add(@geomEditor, 1, EXPAND)
        # @calcTree.hide
        # panel.layout
        
        # @tree = ProjectTree.new(self, hsplitter)
        @inspector = Inspector.new(self, @frame)
        @frame.set_menu_bar(menubar)
        @toolbar = @frame.create_tool_bar
        populate_toolbar(@toolbar) if @toolbar
                
        # Add to split view
        # hsplitter.split_vertically(@tree, splitter, 150)
        # splitter.split_horizontally(@geomViewer, panel, 550)
        
        # Check off the current tool
        set_tool
        
        # Display
        @frame.show        
   end
   
   # Process a menu event
   def process_menu_event(event)
     case event.id
     when ID_ROTATE
       @geomViewer.set_mouse_motion_function(:rotate)
     when ID_ZOOM
       @geomViewer.set_mouse_motion_function(:zoom)
     when ID_PAN
       @geomViewer.set_mouse_motion_function(:pan)  
     when ID_MOVE_CLIP_PLANE
       @geomViewer.set_mouse_motion_function(:move_clip_plane)
     when ID_INSPECTOR
       show_inspector
     when ID_DELETE_ATOM
       delete_atom
     when Wx::ID_OPEN
       open_file
     when Wx::ID_SAVE
       save_geometry
     when ID_SAVE_IMAGE
       save_image
     when Wx::ID_EXIT
        exit(0)
     else
       event.skip
     end
     set_tool
     
   end
   
   # Clear then populate the toolbar
   def populate_toolbar(tb)
     tb.clear_tools
     
     basedir = File.dirname(__FILE__)
     rotate_icon = Image.new(File.join(basedir,"rotate.gif"), BITMAP_TYPE_GIF)
     @rotate_tool = tb.add_item(rotate_icon.rescale(16,15).convert_to_bitmap,:label => "rotate", :id => ID_ROTATE)
     
     zoom_icon = Image.new(File.join(basedir,"zoom.gif"), BITMAP_TYPE_GIF)
     @zoom_tool = tb.add_item(zoom_icon.rescale(16,15).convert_to_bitmap, :label => "zoom", :id => ID_ZOOM)
     
     pan_icon = Image.new(File.join(basedir,"pan.gif"), BITMAP_TYPE_GIF)
     @pan_tool = tb.add_item(pan_icon.rescale(16,15).convert_to_bitmap, :label => "pan", :id => ID_PAN)
     
     #tb.set_bitmap_size(Size.new(16,15))
     tb.realize
   end
   
   # Return the menubar.  If it is undefined, then define it and attach the event handler
   def menubar
     unless @menubar
       fileMenu = Menu.new
       fileMenu.append(Wx::ID_OPEN, "Open ...\tCTRL+o")
       fileMenu.append(Wx::ID_SAVE, "Save Geometry ...\tCTRL+s")
       fileMenu.append(ID_SAVE_IMAGE, "Export Image ...")
       fileMenu.append(Wx::ID_EXIT, "Exit")
       
       editMenu = Menu.new
       editMenu.append(ID_DELETE_ATOM, "Delete Atom\tCTRL+d")
       
       toolsMenu = Menu.new       
       toolsMenu.append(ID_ROTATE, "rotate", "Rotate", Wx::ITEM_CHECK)
       toolsMenu.append(ID_ZOOM, "zoom", "Zoom", Wx::ITEM_CHECK)
       toolsMenu.append(ID_PAN, "pan", "Pan", Wx::ITEM_CHECK)
       toolsMenu.append(ID_MOVE_CLIP_PLANE, "move cilp plane", "Move", Wx::ITEM_CHECK)
       
       viewMenu = Menu.new
       viewMenu.append(ID_INSPECTOR, "inspector\tCTRL+i")
       
       
       @menubar = MenuBar.new
       @menubar.append(fileMenu, "File")
       @menubar.append(editMenu, "Edit")
       @menubar.append(viewMenu, "Views")
       @menubar.append(toolsMenu, "Tools")
       
       evt_menu @menubar, :process_menu_event
     end
     @menubar
   end
   
   def delete_atom
     @geomViewer.delete_atom
   end
   
   def nudge_selected_atoms(x,y,z)
     if @selection[:atoms]
       @selection[:atoms].each{|a| a.displace!(x,y,z)}
     end
     update_viewer
   end
   
   def select_atom(atom)
     @selection[:atoms] = [atom]
     @geomEditor.select_atom(atom)
   end
   
   # Apply UI settings to viewer and re-render
   def update_viewer
     
     if @original_uc and @inspector.update_unit_cell
       if @inspector.correct
         # @geomViewer.unit_cell = @original_uc.correct
         new_geom = @original_uc.repeat(@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat).correct
       else
         # @geomViewer.unit_cell = @original_uc
         new_geom = @original_uc.repeat(@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat)
       end
       @geomViewer.unit_cell = new_geom
       @geomEditor.unit_cell = new_geom
       @inspector.update_unit_cell = false
     end
     
     # @geomViewer.repeat = [@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat]
     @geomViewer.show_bonds = @inspector.show_bonds
     @geomViewer.bond_length = @inspector.bond_length
     @geomViewer.lighting = @inspector.show_lighting
     @geomViewer.show_supercell = @inspector.show_cell
     @geomViewer.show_xclip = @inspector.show_xclip
     @geomViewer.show_yclip = @inspector.show_yclip
     @geomViewer.show_zclip = @inspector.show_zclip
     @geomViewer.background.alpha = ((@inspector.transparent_bg) ? 0 : 1)
     @geomViewer.draw_scene
   end

   def update
     begin
       uc = Aims::GeometryParser.parse_string(@geomEditor.get_contents)
       @original_uc = uc
       @geomViewer.unit_cell = @original_uc
       
       update_viewer
       @statusbar.status_text = "Ok!"
     rescue Exception => e 
       @statusbar.status_text = e.message
     end
  end
   
   
   # Show the inspector
   def show_inspector
     @inspector.show(true)
   end
   
   # Hide the inspector
   def hide_inspector
     @inspector.hide
   end
   
   def show_calculation(calc)
     begin

       @original_uc = calc.final_geometry
       @calcViewer.unit_cell = @original_uc
       @calcTree.show_calculation(calc)
       @calcTree.show
       @calcTree.parent.layout
#       @geomEditor.unit_cell = @original_uc
       @inspector.update(@geomViewer)
       @calcViewer.draw_scene
       
     rescue $! => e
       error_dialog(e)
     end
   end
   
   # Display the given geometry
   def show_geometry(geometry)
     @original_uc = geometry
     @geomViewer.unit_cell = @original_uc
     @geomEditor.unit_cell = @original_uc
     @inspector.update(@geomViewer)
     @geomViewer.draw_scene
   end
   
   # Display a file dialog and attempt to open and display the file
   def open_geometry_file(file = nil)
     begin
       unless file
         fd = FileDialog.new(@frame, :message => "Open", :style => FD_OPEN, :default_dir => @working_dir)
         if ID_OK == fd.show_modal
           file = fd.get_path
           @working_dir = fd.get_directory
         else
           return
         end
       end
       puts "Opening #{file}"

       @frame.set_title(file)
       @geomEditor.show
       @calcTree.hide
       
       if (project)
         erb = ERB.new(File.read(file))
         show_geometry Aims::GeometryParser.parse_string(erb.result(project.get_binding))
       else
         show_geometry Aims::GeometryParser.parse(file)
       end
       
       
     rescue Exception => dang
       error_dialog(dang)
     end
   end
   alias_method :open_file, :open_geometry_file
   
   # Save the geometry
   def save_geometry
     fd = FileDialog.new(@frame, :message => "Save Geometry", :style => FD_SAVE, :default_dir => @working_dir)
     if Wx::ID_OK == fd.show_modal
       begin
         File.open(fd.get_path, "w") do |f|
           f.puts @geomViewer.current_unit_cell.format_geometry_in
         end
         @working_dir = fd.get_directory
       rescue Exception => e
         error_dialog(e)
       end
     end 
   end

   # Display an error dialog for the exception
   def error_dialog(exception)
     MessageDialog.new(@frame, exception.message, "Error", Wx::ICON_ERROR).show_modal
   end
   
   # Check/Uncheck the appropriate tools in the menu and toolbar
   def set_tool
      current_tool = id_for_tool(@geomViewer.mouse_motion_func)
      [ID_ROTATE, ID_ZOOM, ID_PAN].each{|id|
        @menubar.check(id, current_tool == id)
      }
   end
   
   # Convert between symbols (nice Ruby) and integers (bad C++)
   def id_for_tool(tool)
      case(tool.to_sym)
      when :rotate
        ID_ROTATE
      when :pan
        ID_PAN
      when :zoom
        ID_ZOOM
      else
        nil
      end
   end

   def save_image

     begin
       fd = FileDialog.new(@frame, :message => "Save Image", :style => FD_SAVE, :default_dir => @working_dir)
       if Wx::ID_OK == fd.show_modal
         @working_dir = fd.get_directory

       		image = Image.new(@geomViewer.width, @geomViewer.height)
          image.set_rgb_data(@geomViewer.rgb_image_data)
          image.set_alpha_data(@geomViewer.alpha_image_data)
          puts "Writing #{fd.get_path}"
          image.mirror(false).save_file(fd.get_path)
        end
      rescue Exception => e
        error_dialog(e)
      end
   	end

end
end

