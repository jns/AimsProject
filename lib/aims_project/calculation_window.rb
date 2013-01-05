module AimsProject

  class CalculationWindow < Wx::Panel

    include Wx
    
    def initialize(app, parent)
      
      super(parent)
      @app = app
      
      # Initialize the selection
      @selection = {}
      
      # The inspector window
      @inspector_window = @app.inspector.add_inspector_window
      
      # Initialize the options for the crystal viewer
      @options = CrystalViewerOptions.new(@inspector_window)
      
      # Top level is a splitter
      topSplitterWindow = SplitterWindow.new(self)
      sizer = VBoxSizer.new
      sizer.add_item(topSplitterWindow, :proportion => 1, :flag => EXPAND)
      
      set_sizer(sizer)
      
      # The top is a list control
      @calcList = ListCtrl.new(topSplitterWindow)
      
      # The bottom is a vertical splitter
      calcWindowSplitter = SplitterWindow.new(topSplitterWindow)
      
      # with a tree and a viewer
      @calcTree = CalculationTree.new(self, calcWindowSplitter)
      @calcViewer = CrystalViewer.new(self, calcWindowSplitter, @options)
      calcWindowSplitter.split_vertically(@calcTree, @calcViewer)

      # Split the top and bottom
      topSplitterWindow.split_horizontally(@calcList, calcWindowSplitter, 100)

      # Populate the calculations list
      @app.project.calculations.sort{|a,b| a.name <=> b.name}.each{|calc|
        li = ListItem.new
        li.set_text(calc.name)
        li.set_data(calc)
        @calcList.insert_item(li)
      }

      # Setup the events
      evt_list_item_selected(@calcList) {|evt|
        show_calculation(evt.get_item.get_data)
      }
      
      evt_thread_callback {|evt|
        puts "evt_thread_callback"
        @calcTree.show_calculation(@calculation)
        if @calculation.final_geometry
          show_geometry(@calculation.final_geometry)
        else
          show_geometry(@calculation.input_geometry)
        end
      }
      
    end

    def show_inspector
      @app.inspector.show_inspector_window(@inspector_window)
    end
    
    def show_calculation(calc)
     begin
       @calculation = calc
       @err = nil
       t = Thread.new(self) { |evtHandler|
         begin
           @app.set_status("Loading #{@calculation.name}")
           @calculation.load_output
           evt = ThreadCallbackEvent.new
           evtHandler.add_pending_event(evt)
           @app.set_status("")
         rescue $! => e
           @app.set_status(e.message)
         end
       }
       t.priority = t.priority + 100
     rescue $! => e
       puts e.message
       puts e.backtrace
       @app.error_dialog(e)
     end
    end

    # get the currently displayed geometry
    def geometry
      @calcViewer.unit_cell
    end

    # Display the given geometry
    def show_geometry(geometry)
      @calcViewer.unit_cell = geometry
      @calcViewer.draw_scene
    end
    
    def select_atom(atom)
      @app.set_status(atom.format_geometry_in)
    end
    
    def nudge_selected_atoms(x,y,z)
      @app.error_dialog("Sorry, 'nudge' doesn't work on calculation outputs.")
    end
    
  end
end