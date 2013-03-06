module AimsProject

  class CalculationWindow < Wx::Panel

    include Wx
    
    CALC_TABLE_COLS=4
    
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
      @calcTable = Grid.new(topSplitterWindow, -1)
      init_table

      # Populate the calculations list
      @calcs = @app.project.calculations.sort{|a,b| a.name <=> b.name}
      @calcs.each_with_index{|calc, i|
        add_calc_at_row(calc, i)
      }
      @calcTable.auto_size

      # The bottom is a vertical splitter
      calcWindowSplitter = SplitterWindow.new(topSplitterWindow)
      
      # with a tree and a viewer
      @calcTree = CalculationTree.new(self, calcWindowSplitter)
      @calcViewer = CrystalViewer.new(self, calcWindowSplitter, @options)
      calcWindowSplitter.split_vertically(@calcTree, @calcViewer)


      # Split the top and bottom
      topSplitterWindow.split_horizontally(@calcTable, calcWindowSplitter, 100)

      # Setup the events
      evt_grid_cmd_range_select(@calcTable) {|evt|
        if evt.selecting
          row = evt.get_top_row
          puts "CalculationWindow.show_calculation #{@calcs[row].calculation_directory}"
          show_calculation(@calcs[row])        
        end
      }
      
      evt_thread_callback {|evt|
        @calcTree.show_calculation(@calculation)
        if @calculation.final_geometry
          show_geometry(@calculation.final_geometry)
        else
          show_geometry(@calculation.input_geometry)
        end
      }
      
    end
    
    def init_table
      @calcTable.create_grid(@app.project.calculations.size, CALC_TABLE_COLS, Grid::GridSelectRows)
      @calcTable.set_col_label_value(0, "Geometry")
      @calcTable.set_col_label_value(1, "Subdirectory")
      @calcTable.set_col_label_value(2, "Control")
      @calcTable.set_col_label_value(3, "Status")
      
    end

    # Insert a calculation in the table at the specified row
    def add_calc_at_row(calc, row)
      @calcTable.set_cell_value(row, 0, calc.geometry)
      @calcTable.set_cell_value(row, 1, calc.calc_subdir.to_s)
      @calcTable.set_cell_value(row, 2, calc.control)
      @calcTable.set_cell_value(row, 3, calc.status)
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

    # Get an Image
    def image
      @calcViewer.image
    end

    # get the currently displayed geometry
    def geometry
      @calcViewer.unit_cell
    end

    # Display the given geometry
    def show_geometry(geometry)
      @calcViewer.unit_cell = GeometryFile.new(geometry)
    end
    
    def select_atom(atom)
      @app.set_status(atom.format_geometry_in)
    end
    
    def nudge_selected_atoms(x,y,z)
      @app.error_dialog("Sorry, 'nudge' doesn't work on calculation outputs.")
    end
    
  end
end