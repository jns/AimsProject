require 'observer'

module AimsProject
  class CrystalViewerOptions
    
    include Wx
    include Observable  
    
      def add_control(name, control)
        instance_variable_set("@#{name.to_s}".to_sym, control)
        instance_eval <<-EOS
          def #{name.to_s}
            @#{name.to_s}.get_value
          end

          def #{name.to_s}=(val)
            @#{name.to_s}.set_value(val)
            changed
            notify_observers
          end
        EOS
        control
      end

  
    def initialize(inspector_window)
      
      # Default padding around each element
      border = 5

      # Main Sizer
      inspector_window.sizer = VBoxSizer.new

      # Panel 1
      panel1 =  VBoxSizer.new
      panel1.add_item(add_control(:show_bonds,  CheckBox.new(inspector_window, :label => 'Show Bonds')), :flag => ALL,:border => border)
      panel1.add_item(add_control(:show_lighting, CheckBox.new(inspector_window, :label => 'Show Lighting')), :flag => ALL, :border => border)
      panel1.add_item(add_control(:show_supercell, CheckBox.new(inspector_window, :label => "Show Unit Cell")), :flag => ALL, :border => border)
      panel1.add_item(add_control(:correct, CheckBox.new(inspector_window, :label => "Correct Geometry")), :flag => ALL, :border => border)
      panel1.add_item(add_control(:solid_bg, CheckBox.new(inspector_window, :label => "Solid BG")), :flag => ALL, :border => border)
      
      gsizer = GridSizer.new(2,1)
      gsizer.add(StaticText.new(inspector_window, :label => "Bond Length"))
      gsizer.add_item(add_control(:bond_length, SpinCtrl.new(inspector_window, :min => 1, :max => 100, :value => "4", :name => "Name")), :flag => EXPAND)
      panel1.add_item(gsizer)
      
      
      # Panel 2 : Clip Planes
      panel2 =  VBoxSizer.new
      panel2.add_item(StaticText.new(inspector_window, -1, "Clip Planes:", :style => ALIGN_LEFT))
      panel2.add_item(add_control(:show_xclip, CheckBox.new(inspector_window, :label => 'x')), :flag => Wx::ALIGN_CENTER, :border => border)
      panel2.add_item(add_control(:show_yclip, CheckBox.new(inspector_window, :label => 'y')), :flag => Wx::ALIGN_CENTER, :border => border)
      panel2.add_item(add_control(:show_zclip, CheckBox.new(inspector_window, :label => 'z')), :flag => Wx::ALIGN_CENTER, :border => border)
      
       # Panel 3: Repeat
       panel3 = VBoxSizer.new
       panel3.add_item(StaticText.new(inspector_window, -1, "Repeat:", :style => ALIGN_LEFT), :flag => EXPAND)
      
       panel3grid = GridSizer.new(3,2, border, border)
       panel3grid.add(StaticText.new(inspector_window, :label => "x", :style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(add_control(:x_repeat, SpinCtrl.new(inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)),2)
      
       panel3grid.add(StaticText.new(inspector_window, :label => "y",:style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(add_control(:y_repeat, SpinCtrl.new(inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)),2)
      
       panel3grid.add(StaticText.new(inspector_window, :label => "z",:style => ALIGN_RIGHT),1, EXPAND)
       panel3grid.add(add_control(:z_repeat, SpinCtrl.new(inspector_window, :value => "1", :min => 1, :max => 100, :initial => 1)),2)
             
       panel3.add_item(panel3grid, :flag => EXPAND | ALIGN_CENTER)

       # Event Handling
       inspector_window.evt_checkbox(@show_bonds) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@show_lighting) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@show_supercell) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@solid_bg) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@correct) {|evt| changed; notify_observers }
       inspector_window.evt_spinctrl(@bond_length) {|evt| changed; notify_observers }
       inspector_window.evt_checkbox(@show_xclip) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@show_yclip) {|evt| changed; notify_observers}
       inspector_window.evt_checkbox(@show_zclip) {|evt| changed; notify_observers}
       inspector_window.evt_spinctrl(@x_repeat) {|evt| changed; notify_observers}
       inspector_window.evt_spinctrl(@y_repeat) {|evt| changed; notify_observers}
       inspector_window.evt_spinctrl(@z_repeat) {|evt| changed; notify_observers}

       # Add sub-panels
       inspector_window.sizer.add_item(panel1, :flag => EXPAND, :proportion => 1)
       inspector_window.sizer.add_spacer(5)
       inspector_window.sizer.add_item(panel2, :flag => EXPAND, :proportion => 1)
       inspector_window.sizer.add_spacer(5)
       inspector_window.sizer.add_item(panel3, :flag => EXPAND, :proportion => 1)
       inspector_window.layout
    end
      
      def set_properties(props)
        props.each{|k,v|
          instance_variable_get("@#{k.to_s}").set_value(v)
        }
        changed
        notify_observers
      end

  end
end