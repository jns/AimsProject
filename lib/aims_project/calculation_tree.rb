module AimsProject

class CalculationTree < Wx::ScrolledWindow
  
  include Wx
    
  attr_accessor :app, :treeControl
  
  def initialize(app, window)
    super(window)
    self.app = app
    
    init_tree
    
    sizer = BoxSizer.new(VERTICAL)
    sizer.add(self.treeControl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)
  end
  
  def init_tree
    @treeControl = Wx::TreeCtrl.new(self)
    root = self.treeControl.add_root("-")
  end
  
  def show_calculation(calc)
    @tree_map = {}
    
    @treeControl.delete_all_items
    root = self.treeControl.add_root(calc.name)
    input_geom = @treeControl.append_item(root, calc.geometry)
    @tree_map[input_geom] = calc.input_geometry
    @treeControl.append_item(root, calc.control)
    @treeControl.append_item(root, calc.status)
    @treeControl.append_item(root, "CONVERGED: #{calc.converged?}")
    # @treeControl.append_item(root, calc.output.total_wall_time)
    if calc.output
      calc.output.geometry_steps.each{|step| 
        step_id = @treeControl.append_item(root, "Step %i" % step.step_num)
        @tree_map[step_id] = step
        @treeControl.append_item(step_id, "Total Energy: %f" % step.total_energy)
        @treeControl.append_item(step_id, "SC Iters: %i" % step.sc_iterations.size)
        @treeControl.append_item(step_id, "Wall Time: %f" % step.total_wall_time.to_s)
      }
    end
    @treeControl.expand(root)
    # self.app.project.calculations.each{|calc|
    #   calcid = self.treeControl.append_item(root, calc.name)
    #   @tree_map[calcid] = calc
    # }
    
    evt_tree_sel_changed(self.treeControl) {|evt|
       item = @tree_map[evt.get_item]
       if item.is_a? Aims::GeometryStep       
         self.app.show_geometry(item.geometry)
       end
       if item.is_a? Aims::Geometry
         self.app.show_geometry(item)
       end
    }
  end
  
end
end