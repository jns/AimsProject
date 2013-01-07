
module AimsProject
class AppController < Wx::App
  
    include Wx
  
    ID_SAVE_IMAGE = 103  
    ID_MOVE_CLIP_PLANE = 104

    ID_INSPECTOR = 201

    ID_DELETE_ATOM = 301
    
    @frame = nil
    @menubar = nil
    @inspector = nil
    @statusbar = nil

    # The project
    attr_accessor :project
    
    # Used to synchronize directory in open/save dialogs
    attr_accessor :working_dir
    
    # The root frame
    attr_accessor :frame
    
   # Build the application
   def on_init
     
        self.app_name = "AimsViewer"
        # Create the frame, toolbar and menubar and define event handlers
        size = [1000,700]
        @frame = Frame.new(nil, -1, "AimsViewer", DEFAULT_POSITION, size)
        @statusbar = @frame.create_status_bar

        # This timer will cause the main thread to pass every 2 ms so that other threads
        # can get work done.
        timer = Wx::Timer.new(self, Wx::ID_ANY)
        evt_timer(timer.id) {Thread.pass}
        timer.start(2)

        # Initialize the selection
        @selection = {}
        
        # Initialize the inspector
        @inspector = Inspector.new(self, @frame)
        
        # Create the notebook
        @notebook = Notebook.new(@frame)
        
        # Create the geometry notebook page
        @geomWindow = GeometryWindow.new(self, @notebook)

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
        calcWindow = CalculationWindow.new(self, @notebook)
        
        # Add windows to the notebook
        @notebook.add_page(@geomWindow, 'Geometry')
        @notebook.add_page(controlWindow, "Control")
        @notebook.add_page(calcWindow, "Calculations")
        
        evt_notebook_page_changed(@notebook) {|evt|
          cp = @notebook.get_current_page
          if cp.respond_to? :show_inspector
            @notebook.get_current_page.show_inspector
          end
        }
        
        # Set the selected notebook page
        @notebook.set_selection(2)
        
        # @tree = ProjectTree.new(self, hsplitter)
        @frame.set_menu_bar(menubar)
        # @toolbar = @frame.create_tool_bar
        # populate_toolbar(@toolbar) if @toolbar
                

        # Check off the current tool
        # set_tool
        
        # Display
        @frame.show        
   end
   
   # Process a menu event
   def process_menu_event(event)
     case event.id
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
     
   end

   
   # Return the menubar.  If it is undefined, then define it and attach the event handler
   def menubar
     unless @menubar
       fileMenu = Menu.new
       fileMenu.append(Wx::ID_OPEN, "Open ...\tCTRL+o")
       fileMenu.append(Wx::ID_SAVE, "Save Geometry As...\tCTRL+s")
       fileMenu.append(ID_SAVE_IMAGE, "Export Image ...")
       fileMenu.append(Wx::ID_EXIT, "Exit")
       
       editMenu = Menu.new
       editMenu.append(ID_DELETE_ATOM, "Delete Atom\tCTRL+d")
       
       toolsMenu = Menu.new       
       # toolsMenu.append(ID_ROTATE, "rotate", "Rotate", Wx::ITEM_CHECK)
       # toolsMenu.append(ID_ZOOM, "zoom", "Zoom", Wx::ITEM_CHECK)
       # toolsMenu.append(ID_PAN, "pan", "Pan", Wx::ITEM_CHECK)
       # toolsMenu.append(ID_MOVE_CLIP_PLANE, "move cilp plane", "Move", Wx::ITEM_CHECK)
       
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
   
   def set_status(string)
     @frame.set_status_text(string)
   end
   
   # Get the inspector
   def inspector
     if @inspector.nil?
       @inspector = Inspector.new(self, @frame)
     end
     @inspector
   end
   
   # Show the inspector
   def show_inspector
     @inspector.show(true)
   end
   
   # Hide the inspector
   def hide_inspector
     @inspector.hide
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
     
     page = @notebook.get_current_page
     if (page.respond_to? :geometry)  && not(page.geometry.nil?)
       geometry = @notebook.get_current_page.geometry
       
       fd = TextEntryDialog.new(@frame, :message => "Save Geometry", :caption => "Specify name of geometry:")
       if Wx::ID_OK == fd.show_modal
         begin
           geom_name = fd.get_value
           geometry.save_as(File.new(geom_name, "w"))
           @geomWindow.add_geometry(geom_name, geometry)
         rescue Exception => e
           error_dialog(e)
         end
       end 
     else
       error_dialog("No geometry selected.")
     end
   end

   # Display an error dialog for the exception
   def error_dialog(exception)
     message = if exception.is_a? String
       exception
     elsif exception.is_a? Exception
       exception.message + "\n\n" + exception.backtrace[0..2].join("\n")
     end
     puts message
     MessageDialog.new(@frame, message, "Error", Wx::ICON_ERROR).show_modal
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

