module AimsProject

class CalculationTree < Wx::ScrolledWindow
  
  include Wx
  
  CALCULATIONS = "Calculations"
  
  
  attr_accessor :app, :treeControl
  
  def initialize(app, window)
    super(window)
    self.app = app
    
    init_calculation_tree
    
    sizer = BoxSizer.new(VERTICAL)
    sizer.add(self.treeControl, 1, EXPAND | ALL, 5)

    set_auto_layout(true)
    set_sizer(sizer)
  end
  
  def init_calculation_tree
    @treeControl = Wx::TreeCtrl.new(self)
    @tree_map = {}
    if self.app.project

      root = self.treeControl.add_root(CALCULATIONS)

      self.app.project.calculations.each{|calc|
        calcid = self.treeControl.append_item(root, calc.name)
        @tree_map[calcid] = calc
      }
      
      evt_tree_sel_changed(self.treeControl) {|evt|
        calcid = evt.get_item        
        # self.app.open_file(self.treeControl.get_item_text(itemid))
      }
    else
      @tree_map[ROOT] = self.treeControl.add_root(ROOT)
    end
  end
  
end
end