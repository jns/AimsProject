module AimsProject
class CrystalViewer < Wx::Panel

  include Wx
  include Math
  include Gl
  include Glu
  include Aims
  
  # An array of Aims::UnitCell's to display
  attr_reader :unit_cell

  # If displaying multiple, then the current cell
  attr_accessor :current_cell

  # Atomic centers closer than this number have bonds drawn. 
  attr_reader :bond_length

  # The keyboard actions
  attr_accessor :mouse_motion_func # a string "rotate", "pan" or "zoom"

  # The background color (glClearColor)
  attr_accessor :background

  attr_accessor :ortho_side, :ortho_zmin, :ortho_zmax
  attr_accessor :x_down, :y_down, :alt, :az, :offx, :offy, :offz
  attr_accessor :orthographic, :width, :height, :picking, :atom, :x_last, :y_last
  attr_accessor :show_bonds, :lighting, :show_supercell, :show_clip_planes
  attr_accessor :show_xclip, :show_yclip, :show_zclip
  
  attr_accessor :xmax_plane, :xmin_plane
  attr_accessor :ymax_plane, :ymin_plane
  attr_accessor :zmax_plane, :zmin_plane

  attr_accessor :slices, :stacks

  attr_accessor :atoms_changed

  def initialize(controller, parent)

    super(parent)
    @controller = controller

    #@glPanel = CalendarCtrl.new(self)
    attrib = [Wx::GL_RGBA, Wx::GL_DOUBLEBUFFER, Wx::GL_DEPTH_SIZE, 24]
    @glPanel = GLCanvas.new(self, -1, [-1, -1], [-1, -1],
                               Wx::FULL_REPAINT_ON_RESIZE, "GLCanvas", attrib)
    vbox_sizer = VBoxSizer.new
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
    
  end

  def set_defaults
    self.current_cell = 0
    self.bond_length = 3
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
    self.show_bonds = true
    self.lighting = true
    self.show_xclip = false
    self.show_yclip = false
    self.show_zclip = true
    self.show_supercell = true
    self.atoms_changed = true
    self.hiRes
    self.mouse_motion_func = :rotate
    
  end


  def nudge(dir)
    @controller.nudge_selected_atoms(dir[0]*0.5, dir[1]*0.5, 0)
  end

=begin
  Set the unit cell to display. 
=end
  def unit_cell=(uc)
    if uc.is_a? Array
      @unit_cell = uc
    else
      @unit_cell = [uc]
    end

    # each bounding box is a 2 element array [max, min]
    bounding_boxes = @unit_cell.collect{|uc| uc.bounding_box(false)}
    xmax = bounding_boxes.max{|a,b| a[0].x <=> b[0].x}[0].x
    xmin = bounding_boxes.min{|a,b| a[1].x <=> b[1].x}[1].x
    ymax = bounding_boxes.max{|a,b| a[0].y <=> b[0].y}[0].y
    ymin = bounding_boxes.min{|a,b| a[1].y <=> b[1].y}[1].y
    zmax = bounding_boxes.max{|a,b| a[0].z <=> b[0].z}[0].z
    zmin = bounding_boxes.min{|a,b| a[1].z <=> b[1].z}[1].z

    @xmax_plane = Plane.new( 1, 0, 0, xmax, 0, 0)
    @xmin_plane = Plane.new(-1, 0, 0, xmin, 0, 0)
    @ymax_plane = Plane.new( 0, 1, 0, 0, ymax, 0)
    @ymin_plane = Plane.new( 0,-1, 0, 0, ymin, 0)
    @zmax_plane = Plane.new( 0, 0, 1, 0, 0, zmax)
    @zmin_plane = Plane.new( 0, 0,-1, 0, 0, zmin)

    @active_clip_plane = @zmin_plane

    # Add clip-planes to each unit cell
    @unit_cell.each{|uc|
      uc.clear_planes
      uc.add_plane(@xmax_plane, false)
      uc.add_plane(@xmin_plane, false)
      uc.add_plane(@ymax_plane, false)
      uc.add_plane(@ymin_plane, false)
      uc.add_plane(@zmax_plane, false)
      uc.add_plane(@zmin_plane, false)
      uc.recache_visible_atoms
      uc.make_bonds(@bond_length)
    }


  end

  def dump_properties
    self.instance_variables.each{|v|
      puts "#{v} = #{self.instance_variable_get(v)}"
    }
  end

  # The currently displayed unit cell
  def current_unit_cell
    self.unit_cell[self.current_cell]
  end

  def dump_geometry
    atoms = self.unit_cell[self.current_cell]
    if atoms
      puts atoms.format_geometry_in
    end
  end

  def bond_length=(l)
    @bond_length = l
    self.unit_cell.each{|uc| uc.make_bonds(l)} if self.unit_cell
  end

  def mouse_down(x,y)
    self.x_down = x
    self.y_down = y
    self.x_last = x
    self.y_last = y	  
    self.loRes
  end

  def mouse_up(x,y)
    return unless self.unit_cell and self.unit_cell[self.current_cell]
    self.atom = pick_object(x,y)
    if self.atom
      @controller.select_atom(self.atom)
      puts self.atom.format_geometry_in
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
      self.unit_cell.each{|uc| 
        uc.remove_atom(self.atom)
      }
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
    self.offx += (x - self.x_last)*0.1
    self.offy -= (y - self.y_last)*0.1
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
    draw_init
    apply_projection
    position_camera
    add_lights if self.lighting
    outline_supercell if self.show_supercell
    draw_bonds if self.show_bonds
    draw_lattice
    draw_clip_planes
    
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
      gluPerspective(60, self.width/self.height, 1, 60)
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

    if self.lighting
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
    glMatrixMode(GL_MODELVIEW)

    glInitNames

    self.draw_lattice

    self.picking = false

    glMatrixMode(GL_MODELVIEW);
    glFlush();

    count = glRenderMode(GL_RENDER)
    data = buf.unpack("I*")
    names = []
    count.times do 
      num_names = data.shift
      min_depth = data.shift
      max_depth = data.shift
      num_names.times do 
        names << data.shift
      end
    end


    self.unit_cell[self.current_cell].find{|a| a.id == names[0]}
  end

  def position_camera
    return unless self.unit_cell
    atoms = self.unit_cell[self.current_cell]
    return unless atoms

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
    light1_position = [-1,-1,-1,0]
    glLightfv(GL_LIGHT0, GL_POSITION, light0_position)              
    glLightfv(GL_LIGHT1, GL_POSITION, light1_position)
  end

  def outline_supercell
    return unless self.unit_cell
    uc = self.unit_cell[self.current_cell]
    return unless uc
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

  def draw_bonds
    return unless self.unit_cell
    atoms = self.unit_cell[self.current_cell]
    return unless atoms

    black = Material.new(0,0,0)
    black.apply(false)
    glBegin(GL_LINES)
    atoms.bonds.each{|b|
      glVertex3f(b[0].x, b[0].y, b[0].z)
      glVertex3f(b[1].x, b[1].y, b[1].z)				
    }
    glEnd()
  end

  def draw_lattice

    return unless self.unit_cell

    atoms = self.unit_cell[self.current_cell]

    return unless atoms

    # Create sphere object
    rmin = 0.3
    rmax = 0.5
    sphere_quadric = gluNewQuadric()
    gluQuadricDrawStyle(sphere_quadric, GLU_FILL)
    gluQuadricNormals(sphere_quadric, GLU_SMOOTH)
    gluQuadricOrientation(sphere_quadric, GLU_OUTSIDE)

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

    for a in atoms
      a.material.apply(self.lighting)
      # Load a new matrix onto the stack
      glPushMatrix()
      glPushName(a.id) if self.picking
      glTranslatef(a.x, a.y, a.z)
      gluSphere(sphere_quadric, rmin+(a.z - zmin)*rscale, slices, stacks)            
      glPopName() if picking
      glPopMatrix()
    end
    gluDeleteQuadric(sphere_quadric)



    # Draw bonds as black lines
    # glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE,[0,0,0,1])
    # glMaterialfv(GL_FRONT_AND_BACK,GL_SPECULAR,[0,0,0,1])
    # self.bonds.draw(GL_LINES)
    # glRasterPos2f(-10, 10)
    # glutBitmapCharacter(GLUT_BITMAP_HELVETICA_18, @@current_cell.to_s[0])
  end

  def draw_clip_planes
    return unless self.unit_cell
    atoms = self.unit_cell[self.current_cell]
    return unless atoms

    bb = atoms.bounding_box
    bbx1 = bb[0].x
    bbx2 = bb[1].x
    bby1 = bb[0].y
    bby2 = bb[1].y
    bbz1 = bb[0].z
    bbz2 = bb[1].z

    Material.new(0.9, 0.9, 0.0, 0.5).apply

    # draw z_planes
    # The are bounded by the min and max points in the x-y plane
    glBegin(GL_QUADS)

    if self.show_zclip
      z = -1*@zmax_plane.distance_to_point(0,0,0)
      glNormal3f(0, 0, 1)
      glVertex3f(bbx1, bby1, z)
      glVertex3f(bbx2, bby1, z)
      glVertex3f(bbx2, bby2, z)
      glVertex3f(bbx1, bby2, z)

      z = @zmin_plane.distance_to_point(0,0,0)
      glNormal3f(0, 0, -1)
      glVertex3f(bbx1, bby1, z)
      glVertex3f(bbx2, bby1, z)
      glVertex3f(bbx2, bby2, z)
      glVertex3f(bbx1, bby2, z)
    end

    if self.show_xclip
      x = -1*@xmax_plane.distance_to_point(0,0,0)
      glNormal3f(1, 0, 0)
      glVertex3f(x, bby1, bbz1)
      glVertex3f(x, bby1, bbz2)
      glVertex3f(x, bby2, bbz2)
      glVertex3f(x, bby2, bbz1)

      x = @xmin_plane.distance_to_point(0,0,0)
      glNormal3f(-1, 0, 0)
      glVertex3f(x, bby1, bbz1)
      glVertex3f(x, bby1, bbz2)
      glVertex3f(x, bby2, bbz2)
      glVertex3f(x, bby2, bbz1)          
    end

    if self.show_yclip
      y = -1*@ymax_plane.distance_to_point(0,0,0)
      glNormal3f(0, 1, 0)
      glVertex3f(bbx1, y, bbz1)
      glVertex3f(bbx1, y, bbz2)
      glVertex3f(bbx2, y, bbz2)
      glVertex3f(bbx2, y, bbz1)

      y = @ymin_plane.distance_to_point(0,0,0)
      glNormal3f(0, -1, 0)
      glVertex3f(bbx1, y, bbz1)
      glVertex3f(bbx1, y, bbz2)
      glVertex3f(bbx2, y, bbz2)
      glVertex3f(bbx2, y, bbz1)          
    end


    glEnd


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

end
end