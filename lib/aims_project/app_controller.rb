
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
    @viewer = nil
    @editor = nil
    @inspector = nil
    @statusbar = nil
    @projectTree = nil

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
        size = [1200,800]
        @frame = Frame.new(nil, -1, "AimsViewer", DEFAULT_POSITION, size)
        @statusbar = @frame.create_status_bar

        # Initialize the selection
        @selection = {}
        
        # Create the split view        
        hsplitter = SplitterWindow.new(@frame)
        splitter = SplitterWindow.new(hsplitter)
                
        @editor = GeometryEditor.new(self, splitter)
        @viewer = CrystalViewer.new(self, splitter)
        @tree = ProjectTree.new(self, hsplitter)
        @inspector = Inspector.new(self, @frame)
        @frame.set_menu_bar(menubar)
        @toolbar = @frame.create_tool_bar
        populate_toolbar(@toolbar) if @toolbar
                
        # Add to split view
        hsplitter.split_vertically(@tree, splitter, 150)
        splitter.split_horizontally(@viewer, @editor, 450)
        
        # Check off the current tool
        set_tool
        
        # Display
        @frame.show        
   end
   
   # Process a menu event
   def process_menu_event(event)
     case event.id
     when ID_ROTATE
       @viewer.set_mouse_motion_function(:rotate)
     when ID_ZOOM
       @viewer.set_mouse_motion_function(:zoom)
     when ID_PAN
       @viewer.set_mouse_motion_function(:pan)  
     when ID_MOVE_CLIP_PLANE
       @viewer.set_mouse_motion_function(:move_clip_plane)
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
     @viewer.delete_atom
   end
   
   def nudge_selected_atoms(x,y,z)
     if @selection[:atoms]
       @selection[:atoms].each{|a| a.displace!(x,y,z)}
     end
     update_viewer
   end
   
   def select_atom(atom)
     @selection[:atoms] = [atom]
     @editor.select_atom(atom)
   end
   
   # Apply UI settings to viewer and re-render
   def update_viewer
     
     if @original_uc and @inspector.update_unit_cell
       if @inspector.correct
         # @viewer.unit_cell = @original_uc.correct
         new_geom = @original_uc.repeat(@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat).correct
       else
         # @viewer.unit_cell = @original_uc
         new_geom = @original_uc.repeat(@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat)
       end
       @viewer.unit_cell = new_geom
       @editor.unit_cell = new_geom
       @inspector.update_unit_cell = false
     end
     
     # @viewer.repeat = [@inspector.x_repeat, @inspector.y_repeat, @inspector.z_repeat]
     @viewer.show_bonds = @inspector.show_bonds
     @viewer.bond_length = @inspector.bond_length
     @viewer.lighting = @inspector.show_lighting
     @viewer.show_supercell = @inspector.show_cell
     @viewer.show_xclip = @inspector.show_xclip
     @viewer.show_yclip = @inspector.show_yclip
     @viewer.show_zclip = @inspector.show_zclip
     @viewer.background.alpha = ((@inspector.transparent_bg) ? 0 : 1)
     @viewer.draw_scene
   end

   def update
     begin
       uc = Aims::GeometryParser.parse_string(@editor.get_contents)
       @original_uc = uc
       @viewer.unit_cell = @original_uc
       
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

       @frame.set_title(calc.name)
       @original_uc = calc.final_geometry
       @viewer.unit_cell = @original_uc
       @editor.unit_cell = @original_uc
       @inspector.update(@viewer)
       @viewer.draw_scene
       
     rescue e
       error_dialog(e)
     end
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
       
       if (project)
         erb = ERB.new(File.read(file))
         @original_uc = Aims::GeometryParser.parse_string(erb.result(project.get_binding))
       else
         @original_uc = Aims::GeometryParser.parse(file)
       end
       
       @frame.set_title(file)
       @viewer.unit_cell = @original_uc
       @editor.unit_cell = @original_uc
       @inspector.update(@viewer)
       @viewer.draw_scene
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
           f.puts @viewer.current_unit_cell.format_geometry_in
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
      current_tool = id_for_tool(@viewer.mouse_motion_func)
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

       		image = Image.new(@viewer.width, @viewer.height)
          image.set_rgb_data(@viewer.rgb_image_data)
          image.set_alpha_data(@viewer.alpha_image_data)
          puts "Writing #{fd.get_path}"
          image.mirror(false).save_file(fd.get_path)
        end
      rescue Exception => e
        error_dialog(e)
      end
   	end

end
end

