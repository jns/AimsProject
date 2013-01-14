module AimsProject
class CrystalViewer < Wx::Panel

  include Wx
  include Math
  include Gl
  include Glu
  include Aims
  
  ID_ROTATE = 100
  ID_PAN = 101
  ID_ZOOM = 102
  
  PICK_ID_ATOM  = 0x10000000
  PICK_ID_PLANE = 0x20000000
  PICK_ID_BOND  = 0x30000000
  
  # An array of Aims::UnitCell's to display
  attr_reader :unit_cell
  attr_reader :unit_cell_corrected

  # How many times to repeat the unit cell
  # A three element vector
  attr_accessor :repeat

  # If displaying multiple, then the current cell
  attr_accessor :current_cell

  # The keyboard actions
  attr_accessor :mouse_motion_func # a string "rotate", "pan" or "zoom"

  # The background color (glClearColor)
  attr_accessor :background

  attr_accessor :ortho_side, :ortho_zmin, :ortho_zmax
  attr_accessor :x_down, :y_down, :alt, :az, :offx, :offy, :offz
  attr_accessor :orthographic, :width, :height, :picking, :atom, :x_last, :y_last
  attr_accessor :render_mode
  
  attr_accessor :xmax_plane, :xmin_plane
  attr_accessor :ymax_plane, :ymin_plane
  attr_accessor :zmax_plane, :zmin_plane

  attr_accessor :slices, :stacks

  attr_accessor :atoms_changed

  attr_accessor :selection

  def initialize(controller, parent, options = nil)

    super(parent)
    @controller = controller
    
    # Register self as an observer of the options
    if options
      @options = options
    else
      @options = CrystalViewerOptions.new(parent)
    end 
    @options.add_observer(self)

    # Toolbar for the GL Canvas
    basedir = File.dirname(__FILE__)
    rotate_icon = Image.new(File.join(basedir,"rotate.gif"), BITMAP_TYPE_GIF)
    @rotate_tool = BitmapButton.new(self, :id => ID_ROTATE, :bitmap => rotate_icon.rescale(16,15).convert_to_bitmap,:name => "rotate")
    
    zoom_icon = Image.new(File.join(basedir,"zoom.gif"), BITMAP_TYPE_GIF)
    @zoom_tool = BitmapButton.new(self, :id => ID_ZOOM, :bitmap => zoom_icon.rescale(16,15).convert_to_bitmap, :name => "zoom")
    
    pan_icon = Image.new(File.join(basedir,"pan.gif"), BITMAP_TYPE_GIF)
    @pan_tool = BitmapButton.new(self, :id => ID_PAN, :bitmap => pan_icon.rescale(16,15).convert_to_bitmap, :name => "pan")

    evt_button(@rotate_tool) {|evt|
      set_mouse_motion_function(:rotate)
    }

    evt_button(@zoom_tool) {|evt|
      set_mouse_motion_function(:zoom)
    }

    evt_button(@pan_tool) {|evt|
      set_mouse_motion_function(:pan)
    }

    @buttonSizer = HBoxSizer.new
    @buttonSizer.add_item(@rotate_tool)
    @buttonSizer.add_item(@zoom_tool)
    @buttonSizer.add_item(@pan_tool)


    #@glPanel = CalendarCtrl.new(self)
    attrib = [Wx::GL_RGBA, Wx::GL_DOUBLEBUFFER, Wx::GL_DEPTH_SIZE, 24]
    @glPanel = GLCanvas.new(self, -1, [-1, -1], [-1, -1],
                               Wx::FULL_REPAINT_ON_RESIZE, "GLCanvas", attrib)
    
    vbox_sizer = VBoxSizer.new
    vbox_sizer.add_item(@buttonSizer, :flag => EXPAND)
    vbox_sizer.add_item(@glPanel, :proportion => 1, :flag => EXPAND)
    set_sizer(vbox_sizer)
    

    set_defaults
    
    # Define the method to call for paint requests
    evt_paint { @glPanel.paint { draw_scene }}
    # Create the graphics view and define event handlers

    # For some reason, not all left-clicks are captured, 
    # so we include this catchall as well, to prevent odd
    # behavior when rotating
    @glPanel.evt_mouse_events {|evt|
      if evt.button_down
        self.set_focus
        mouse_down(evt.get_x, evt.get_y)
      end
    }
    
    @glPanel.evt_left_up {|evt|
      mouse_up(evt.get_x, evt.get_y)
      draw_scene
    }
    
    @glPanel.evt_motion {|evt|
      if evt.dragging
        mouse_dragged(evt.get_x, evt.get_y)
        draw_scene
      end
    }
    
    @glPanel.evt_char {|evt| 
      nudge_dir = case evt.get_key_code
          when K_LEFT
            [-1,0,0]
          when K_RIGHT
            [1,0,0]
          when K_UP
            [0,1,0]
          when K_DOWN
            [0,-1,0]
          else
            [0,0,0]
          end
        nudge(nudge_dir)
    }
    
      # What to do when worker threads return
      evt_thread_callback {|evt|
        self.draw_scene
      }
  end

  # Called when the options changes
  def update
    self.draw_scene
  end

  def set_defaults
    self.current_cell = 0
    self.background = Material.new(0.7, 0.7, 1.0, 1)
    self.x_down = 0
    self.y_down = 0
    self.x_last = 0
    self.y_last = 0
    self.alt = 0
    self.az = 0
    self.offx = 0
    self.offy = 0
    self.offz = -20
    self.orthographic = true
    self.ortho_side = 15
    self.ortho_zmin = -1
    self.ortho_zmax = 50
    self.width = 500
    self.height = 500
    self.picking =false      
    # The last clicked atom
    self.atom = nil
    self.atoms_changed = true
    self.hiRes
    self.mouse_motion_func = :rotate
    self.repeat = Vector[1,1,1]
    self.render_mode = :ball_stick
    @options.set_properties(
      :bond_length => 3,
      :show_bonds => true,
      :show_lighting => true,
      :show_xclip => false,
      :show_yclip => false,
      :show_zclip => true,
      :show_supercell => true
    )
  end


  def nudge(dir)
    @controller.nudge_selected_atoms(dir[0]*0.5, dir[1]*0.5, 0)
  end


=begin
  Set the unit cell to display. 
=end
  def unit_cell=(uc)

    if @unit_cell
      @unit_cell.delete_observer(self)
    end
    
    @unit_cell = uc
    @unit_cell_corrected = nil

    init_clip_planes
    
    @unit_cell.add_observer(self, :unit_cell_changed)

  end

  def unit_cell_changed
    init_clip_planes
    draw_scene
  end

  def init_clip_planes

      Thread.new(self) { |evtHandler|
        @unit_cell_corrected = @unit_cell.correct
        evt = ThreadCallbackEvent.new
        evtHandler.add_pending_event(evt)
      }
    
      # each bounding box is a 2 element array [max, min]
      bounding_box = @unit_cell.bounding_box(false)
      xmax = bounding_box[0].x
      xmin = bounding_box[1].x
      ymax = bounding_box[0].y
      ymin = bounding_box[1].y
      zmax = bounding_box[0].z
      zmin = bounding_box[1].z

      @xmax_plane = Plane.new( 1, 0, 0, xmax, 0, 0)
      @xmin_plane = Plane.new(-1, 0, 0, xmin, 0, 0)
      @ymax_plane = Plane.new( 0, 1, 0, 0, ymax, 0)
      @ymin_plane = Plane.new( 0,-1, 0, 0, ymin, 0)
      @zmax_plane = Plane.new( 0, 0, 1, 0, 0, zmax)
      @zmin_plane = Plane.new( 0, 0,-1, 0, 0, zmin)

      # Add clip-planes to each unit cell
      @unit_cell.clear_planes
      @unit_cell.add_plane(@xmax_plane, false)
      @unit_cell.add_plane(@xmin_plane, false)
      @unit_cell.add_plane(@ymax_plane, false)
      @unit_cell.add_plane(@ymin_plane, false)
      @unit_cell.add_plane(@zmax_plane, false)
      @unit_cell.add_plane(@zmin_plane, false)
      @unit_cell.recache_visible_atoms
      @unit_cell.make_bonds(@options.bond_length)
    
  end

  def dump_properties
    self.instance_variables.each{|v|
      puts "#{v} = #{self.instance_variable_get(v)}"
    }
  end

  # The currently displayed unit cell
  def current_unit_cell
    self.unit_cell
  end

  def dump_geometry
    atoms = self.unit_cell
    if atoms
      puts atoms.format_geometry_in
    end
  end

  def bond_length=(l)
    @options.bond_length = l
    # FIXME The bonds should be made in the controller
    # self.unit_cell.each{|uc| uc.make_bonds(l)} if self.unit_cell
  end

  def mouse_down(x,y)
    self.x_down = x
    self.y_down = y
    self.x_last = x
    self.y_last = y	  
    self.loRes
  end

  def mouse_up(x,y)
    return unless self.unit_cell
    @picked = pick_object(x,y)
    self.atom = self.unit_cell.atoms.find{|a| a.id == @picked[:atoms].last}
    if self.atom
      @controller.select_atom(self.atom)
      # puts self.atom.format_geometry_in
    end
    
    unless @picked[:planes].empty?
      clip_plane_id = @picked[:planes].first
      @active_clip_plane = case clip_plane_id
      when 1 
        @zmax_plane
      when 2
        @zmin_plane
      when 3
        @xmax_plane
      when 4
        @xmin_plane
      when 5
        @ymax_plane
      when 6
        @ymin_plane
      else
        nil
      end
      if @active_clip_plane
        set_mouse_motion_function(:move_clip_plane)
      end
    end
    self.hiRes

    # Harmless correction for bug in WxRuby that doesn't register all mouse down events
    self.x_last = nil
    self.y_last = nil

    glutPostRedisplay if @using_glut
  end

  def mouse_dragged(x, y)

    # Harmless correction for bug in WxRuby that doesn't register all mouse down events
    self.x_last = x if self.x_last.nil?
    self.y_last = y if self.y_last.nil? 

    case self.mouse_motion_func
    when :rotate 
      rotate(x,y)
    when :zoom
      zoom(x,y)
    when :pan
      pan(x,y)
    when :move_clip_plane
      move_clip_plane(x,y)
    else
      rotate(x,y)
    end
    glutPostRedisplay if @using_glut
  end

  def delete_atom
    if self.atom
      # Remove 
      self.unit_cell.remove_atom(self.atom)
    end
  end
  

  def move_clip_plane(x,y)
    scale = 0.1
    dx = (x - self.x_last)
    dy = (y - self.y_last)
    dr = sqrt(dx*dx + dy*dy)*(0 > dy ? -1 : 1)*scale
    self.x_last = x
    self.y_last = y

    @active_clip_plane.displace_along_normal(dr)
    self.atoms_changed = true
  end

  def rotate(x,y)
    self.az += 5*(x - self.x_last)
    self.alt += 5*(y - self.y_last)
    self.x_last = x
    self.y_last = y
  end

  def zoom(x,y)
    if self.orthographic
      self.ortho_side -= (y - self.y_last)*0.1
    else
      self.offz -= (y - self.y_last)*0.1
    end
    self.x_last = x
    self.y_last = y
  end

  def pan(x,y)
    # self.offx += sin(self.alt)*cos(self.az)*(x - self.x_last)*0.1
    #     self.offy -= sin(self.alt)*sin(self.az)*(y - self.y_last)*0.1
    #     self.offz += cos(self.alt)*(x-self.x_last)*0.1
    self.offx += x - self.x_last
    self.offy += y - self.y_last
    
    self.x_last = x
    self.y_last = y
  end

  def loRes
    self.slices = 5
    self.stacks = 5
  end

  def hiRes
    self.slices = 20
    self.stacks = 20
  end

  def set_view(offset_x, offset_y, offset_z, alt, az)
    self.offx = offset_x
    self.offy = offset_y
    self.offz = offset_z
    self.alt = alt
    self.az = az
  end

  # Executes the named method when the mouse is dragged
  def set_mouse_motion_function(method_name)
    self.mouse_motion_func = method_name.to_sym
  end

  def draw_scene
    
    @glPanel.set_current
    sz = @glPanel.size
    viewport_setup(sz.width, sz.height)    
    
    
    begin
      draw_init
      apply_projection
      position_camera
      add_lights if @options.show_lighting
      outline_supercell if @options.show_supercell
      
      if self.unit_cell
        atoms = self.unit_cell
        @options.x_repeat.times do |i|
          @options.y_repeat.times do |j|
            @options.z_repeat.times do |k|
            
              origin = atoms.lattice_vectors[0]*i + atoms.lattice_vectors[1]*j + atoms.lattice_vectors[2]*k

              draw_bonds(origin) if @options.show_bonds
              draw_lattice(origin)
            end
          end
        end
      end
      draw_clip_planes
    rescue AimsProjectException => e
      puts e.message
      puts e.backtrace.join("\n")
    end
    
    @glPanel.swap_buffers
  end

  def viewport_setup(width, height)
    self.width = width
    self.height = height
    glViewport(0, 0, self.width, self.height)
  end

  def apply_projection
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    if self.orthographic
      glOrtho(-self.ortho_side, self.ortho_side, -self.ortho_side,self.ortho_side, self.ortho_zmin, self.ortho_zmax)
    else
      gluPerspective(60, self.width/self.height, 1, 120)
    end
    glMatrixMode(GL_MODELVIEW)
  end

  def draw_init
    glClearColor(background.r,background.g,background.b,background.alpha)
    glEnable(GL_DEPTH_TEST)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)


    # Antialiasing
    glEnable(GL_LINE_SMOOTH)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST)

    if @options.show_lighting
      glEnable(GL_LIGHTING)
      glEnable(GL_LIGHT0)
    else
      glDisable(GL_LIGHTING)
    end

    # Point size
    glPointSize(5)
    glLineWidth(2)
  end

  def pick_object(x,y)

    buf = glSelectBuffer(512)
    glRenderMode(GL_SELECT)
    model = glGetDoublev(GL_MODELVIEW_MATRIX)
    proj = glGetDoublev(GL_PROJECTION_MATRIX)
    viewport = glGetIntegerv(GL_VIEWPORT);
    
    self.picking = true
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPickMatrix(x,viewport[3]-y,5,5,viewport)
    if self.orthographic
      glOrtho(-self.ortho_side, self.ortho_side, -self.ortho_side,self.ortho_side, self.ortho_zmin, self.ortho_zmax)
    else
      gluPerspective(60, self.width/self.height, 1, 60)
    end
    
    z = 0.0 # This value is normalized with respect to the near and far clip planes
    obj_x, obj_y, obj_z = gluUnProject(x, viewport[3]-y, z, model, proj, viewport)
    puts "obj_x = #{obj_x}, obj_y = #{obj_y}, obj_z = #{obj_z}"
    
    glMatrixMode(GL_MODELVIEW)

    glInitNames
    if self.unit_cell
      atoms = self.unit_cell
      @options.x_repeat.times do |i|
        @options.y_repeat.times do |j|
          @options.z_repeat.times do |k|
            
            origin = atoms.lattice_vectors[0]*i + atoms.lattice_vectors[1]*j + atoms.lattice_vectors[2]*k

            self.draw_lattice(origin)
            self.draw_clip_planes
          end
        end
      end
    end

    self.picking = false

    glMatrixMode(GL_MODELVIEW);
    glFlush();

    count = glRenderMode(GL_RENDER)
    data = buf.unpack("L!*")
    names = []
    count.times do 
      num_names = data.shift
      min_depth = data.shift
      max_depth = data.shift
      num_names.times do 
        names << data.shift
      end
    end

    picked_objects = {:atoms => [], :planes => [], :bonds => []}
    names.each{|n|
      if (n & PICK_ID_ATOM) == PICK_ID_ATOM
        picked_objects[:atoms] << (n ^ PICK_ID_ATOM)
      end
      if (n & PICK_ID_PLANE) == PICK_ID_PLANE
        picked_objects[:planes] << (n ^ PICK_ID_PLANE)
      end
    }

    picked_objects
  end

  def position_camera
    return unless self.unit_cell
    atoms = self.unit_cell
    
    # Find the center of all atoms, not just visible ones.
    center = atoms.center

    # Move camera out along z-axis
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

    glTranslatef(self.offx,self.offy,self.offz)
    glRotatef(self.alt, 1, 0, 0)
    glRotatef(self.az, 0, 0, 1)
    glTranslatef(-center.x, -center.y, -center.z)
  end

  def add_lights
    light0_position = [1,1,1,0]
    light1_position = [-1,-1,1,1]
    glLightModel(GL_LIGHT_MODEL_AMBIENT, [0.6, 0.6, 0.6 ,1.0])
    # glLightModel(GL_LIGHT_MODEL_LOCAL_VIEWER, GL_TRUE)
    glLightfv(GL_LIGHT0, GL_POSITION, light0_position)              
    glLightfv(GL_LIGHT1, GL_POSITION, light1_position)
  end

  def outline_supercell
    return unless self.unit_cell
    uc = self.unit_cell

    vecs = uc.lattice_vectors
    return unless vecs

    origin = [0, 0, 0]
    v1 = vecs[0]
    v2 = vecs[1]
    v3 = vecs[2]

    # Corner #1
    c1 = v1 + v3

    # Corner #2
    c2 = v2 + v3

    # Corner #3
    c3 = v1 + v2

    # Corner #4
    c4 = v1 + v2 + v3

    Material.black.apply
    glLineWidth(1.0)

    glBegin(GL_LINES)

    glVertex3f(origin[0], origin[1], origin[2])
    glVertex3f(v1[0], v1[1], v1[2])				

    glVertex3f(origin[0], origin[1], origin[2])
    glVertex3f(v2[0], v2[1], v2[2])       

    glVertex3f(origin[0], origin[1], origin[2])
    glVertex3f(v3[0], v3[1], v3[2])       

    glVertex3f(v1[0], v1[1], v1[2])
    glVertex3f(c3[0], c3[1], c3[2])       

    glVertex3f(v2[0], v2[1], v2[2])
    glVertex3f(c3[0], c3[1], c3[2])       

    glVertex3f(c3[0], c3[1], c3[2])       
    glVertex3f(c4[0], c4[1], c4[2])       

    glVertex3f(v1[0], v1[1], v1[2])
    glVertex3f(c1[0], c1[1], c1[2])       

    glVertex3f(v2[0], v2[1], v2[2])
    glVertex3f(c2[0], c2[1], c2[2])       

    glVertex3f(c1[0], c1[1], c1[2])       
    glVertex3f(c4[0], c4[1], c4[2])       

    glVertex3f(c2[0], c2[1], c2[2])       
    glVertex3f(c4[0], c4[1], c4[2])       

    glVertex3f(v3[0], v3[1], v3[2])
    glVertex3f(c1[0], c1[1], c1[2])       

    glVertex3f(v3[0], v3[1], v3[2])
    glVertex3f(c2[0], c2[1], c2[2])       

    glEnd()        
  end

  def draw_bonds(origin = [0,0,0])
    return unless self.unit_cell
    atoms = if @options.correct
      @unit_cell_corrected
    else
        @unit_cell
    end

    Material.black.apply
    glLineWidth(1.0)
    glBegin(GL_LINES)
    atoms.bonds.each{|b|
      glVertex3f(origin[0] + b[0].x, origin[1] + b[0].y, origin[2] + b[0].z)
      glVertex3f(origin[0] + b[1].x, origin[1] + b[1].y, origin[2] + b[1].z)				
    }
    glEnd()
  end
  
  # 
  # Draw an atom 
  # @param x The x-coordinate
  # @param y The y-coordinate
  # @param z The z-coordinate
  # @param r The radius
  # @param name The name of the sphere (for picking)
  # @return a sphere_quadric for reuse if desired. Make sure to delete it when done
  def draw_sphere(x,y,z,r, name, sphere_quadric=nil)

    unless sphere_quadric 
      sphere_quadric = gluNewQuadric()
      gluQuadricDrawStyle(sphere_quadric, GLU_FILL)
      gluQuadricNormals(sphere_quadric, GLU_SMOOTH)
      gluQuadricOrientation(sphere_quadric, GLU_OUTSIDE)
    end

    # Load a new matrix onto the stack
    glPushMatrix()
    glPushName(name | PICK_ID_ATOM) if self.picking
    glTranslatef(x, y, z)
    gluSphere(sphere_quadric, r, slices, stacks)            
    glPopName() if picking
    glPopMatrix()
    
    sphere_quadric
  end

  def draw_lattice(origin = [0,0,0])

    return unless self.unit_cell
    
    atoms = if @options.correct
      @unit_cell_corrected
    else
      @unit_cell
    end
    
    return unless atoms
    
    # Create sphere object
    rmin = 0.3
    rmax = 0.5

    # Calculate radius scaling factor vs. depth
    rrange = rmax - rmin
    bb = atoms.bounding_box
    zmin = bb[0].z < bb[1].z ? bb[0].z : bb[1].z
    zmax = bb[0].z < bb[1].z ? bb[1].z : bb[0].z
    zrange = zmax - zmin
    if zrange == 0
      rscale = 0
    else
      rscale = rrange/zrange
    end

    if self.atoms_changed
      atoms.recache_visible_atoms 
      self.atoms_changed = false
    end

    sphere_quadric = nil
    for a in atoms
      a.material.apply(@options.show_lighting)
      case self.render_mode 
      when :ball_stick
        r = rmin+(a.z - zmin)*rscale
      else
        r = 2.0
      end
      
      sphere_quadric = draw_sphere(origin[0] + a.x, origin[1] + a.y, origin[2] + a.z, r, a.id, sphere_quadric)
      
    end
    gluDeleteQuadric(sphere_quadric) if sphere_quadric

  end

  # a test method to see of an object of a particular type was picked.
  # valid types are :atom, :plane 
  def is_picked?(type, id)
    if @picked
    case type
      when :atom
        @picked[:atoms].member? id
      when :plane
        @picked[:planes].member? id
      when :bond
        @picked[:bonds].member? id
      else
        false
      end
    else
      false
    end
  end

  #
  # Draw a plane
  # use the vertices defined in lineLoop as the boundary of the plane
  def draw_plane(plane, lineLoop, pickid)

    glPushName(pickid | PICK_ID_PLANE) if self.picking
    
    # if is_picked?(:plane, pickid)
    #   Material.black.apply
    #   glLineWidth(3.0)
    #   glEdgeFlag(GL_TRUE)
    # end
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)

    Material.new(0.9, 0.9, 0.0, 0.5).apply
    glBegin(GL_TRIANGLE_FAN)
    glNormal3f(plane.a, plane.b, plane.c)
    lineLoop.each{|p| 
        glVertex3f(p[0], p[1], p[2])
    }
    glEnd()
    
    glEdgeFlag(GL_FALSE)
    glPopName() if picking
    
    if (is_picked?(:plane, pickid))
      Material.black.apply
      glLineWidth(3.0)
      glBegin(GL_LINE_LOOP)
      lineLoop.each{|p|
        glVertex3f(p[0], p[1], p[2])
      }
      glEnd()
      glLineWidth(1.0)
    end
    
  end

  def draw_clip_planes
    return unless self.unit_cell
    atoms = self.unit_cell

    bb = atoms.bounding_box
    bbx1 = bb[0].x
    bbx2 = bb[1].x
    bby1 = bb[0].y
    bby2 = bb[1].y
    bbz1 = bb[0].z
    bbz2 = bb[1].z

    # draw z_planes
    # The are bounded by the min and max points in the x-y plane

    if @options.show_zclip
      z = -1*@zmax_plane.distance_to_point(0,0,0)
      draw_plane(@zmax_plane, [[bbx1, bby1, z],
                               [bbx2, bby1, z],
                               [bbx2, bby2, z], 
                               [bbx1, bby2, z]],1)

       z = @zmin_plane.distance_to_point(0,0,0)
       draw_plane(@zmin_plane, [[bbx1, bby1, z],
                                [bbx2, bby1, z],
                                [bbx2, bby2, z], 
                                [bbx1, bby2, z]],2)
    end

    if @options.show_xclip
      x = -1*@xmax_plane.distance_to_point(0,0,0)
      draw_plane(@xmax_plane, [[x, bby1, bbz1],
                               [x, bby1, bbz2],
                               [x, bby2, bbz2], 
                               [x, bby2, bbz1]],3)

       x = @xmin_plane.distance_to_point(0,0,0)
       draw_plane(@xmin_plane, [[x, bby1, bbz1],
                                [x, bby1, bbz2],
                                [x, bby2, bbz2], 
                                [x, bby2, bbz1]],4)
    end

    if @options.show_yclip
      y = -1*@ymax_plane.distance_to_point(0,0,0)
      draw_plane(@ymax_plane, [[bbx1, y, bbz1],
                               [bbx1, y, bbz2],
                               [bbx2, y, bbz2], 
                               [bbx2, y, bbz1]],5)

       y = @ymin_plane.distance_to_point(0,0,0)
       draw_plane(@ymin_plane, [[bbx1, y, bbz1],
                                [bbx1, y, bbz2],
                                [bbx2, y, bbz2], 
                                [bbx2, y, bbz1]],6)
    end

  end

  def rgba_image_data

    # 4 bytes/pixel
    bytewidth = self.width*4
    bytewidth = (bytewidth.to_i + 3) & ~3 # Align to 4 bytes
    bytes = bytewidth * self.height

    # Finish any pending Commands
    @glPanel.set_current
    glFinish

    # Setup pixel store
    glPixelStorei(Gl::GL_PACK_ALIGNMENT, 4) # Force 4-byte alignment
    glPixelStorei(Gl::GL_PACK_ROW_LENGTH, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_ROWS, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_PIXELS, 0)

    glReadPixels(0, 0, self.width, self.height, Gl::GL_RGBA, Gl::GL_UNSIGNED_BYTE)

  end

  def rgb_image_data

    # 3 bytes/pixel
    bytewidth = self.width*3
    bytes = bytewidth * self.height

    # Finish any pending Commands
    @glPanel.set_current
    glFinish

    # Setup pixel store
    glPixelStorei(Gl::GL_PACK_ALIGNMENT, 1) # Force byte alignment
    glPixelStorei(Gl::GL_PACK_ROW_LENGTH, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_ROWS, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_PIXELS, 0)

    glReadPixels(0, 0, self.width, self.height, Gl::GL_RGB, Gl::GL_UNSIGNED_BYTE)

  end
  
  def alpha_image_data
    # 1 byte/pixel
    bytewidth = self.width;
    
    bytes = bytewidth*height;
    @glPanel.set_current
    glFinish

    # Setup pixel store
    glPixelStorei(Gl::GL_PACK_ALIGNMENT, 1) # Force byte alignment
    glPixelStorei(Gl::GL_PACK_ROW_LENGTH, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_ROWS, 0)
    glPixelStorei(Gl::GL_PACK_SKIP_PIXELS, 0)
    
    glReadPixels(0, 0, self.width, self.height, Gl::GL_ALPHA, Gl::GL_UNSIGNED_BYTE)
  end

end
end