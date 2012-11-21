module AimsProject

class ProjectTree < Wx::ScrolledWindow
  
  include Wx
  
  ROOT = "Root"
  GEOMETRY = "Geometry"
  CONTROL = "Control"
  CALCULATIONS = "Calculations"
  
  
  attr_accessor :app, :treeControl
  
  def initialize(app, window)
    super(window)
    self.app = app
    
    init_project_tree
    
    sizer = BoxSizer.new(VERTICAL)
    sizer.add(self.treeControl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)
  end
  
  def init_project_tree
    @treeControl = Wx::TreeCtrl.new(self)
    @tree_map = {}
    if self.app.project
      @tree_map[ROOT] = self.treeControl.add_root(self.app.project.name)
      @tree_map[GEOMETRY] = self.treeControl.append_item(@tree_map[ROOT], GEOMETRY)
      @tree_map[CONTROL] = self.treeControl.append_item(@tree_map[ROOT], CONTROL)
      @tree_map[CALCULATIONS] = self.treeControl.append_item(@tree_map[ROOT], CALCULATIONS)

      self.app.project.geometries.each{|geom|
        self.treeControl.append_item(@tree_map[GEOMETRY], geom)
      }

      self.app.project.calculations.each{|calc|
        calcid = self.treeControl.append_item(@tree_map[CALCULATIONS], calc.name)
        @tree_map[calcid] = calc
      }
      
      evt_tree_sel_changed(self.treeControl) {|evt|
        itemid = evt.get_item
        if @tree_map[GEOMETRY] == self.treeControl.get_item_parent(itemid)
          self.app.open_file(self.treeControl.get_item_text(itemid))
        elsif @tree_map[CALCULATIONS] == self.treeControl.get_item_parent(itemid)
          calc = @tree_map[itemid]
          self.app.show_calculation(calc)
        end
      }
    else
      @tree_map[ROOT] = self.treeControl.add_root(ROOT)
    end
    @treeControl.expand(@tree_map[ROOT])
  end
  
end
end