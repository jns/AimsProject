class Material

  include Gl
  
  attr_accessor :r, :g, :b, :alpha

def initialize(r,g,b,alpha=1)
        self.r = r
        self.g = g
        self.b = b
        self.alpha = alpha
    end
  
    def apply(lighting = true)
	if lighting
		glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, [self.r, self.g, self.b, self.alpha])
		glMaterialfv(GL_FRONT, GL_SPECULAR, [self.r, self.g, self.b, self.alpha])
		glMaterialf(GL_FRONT, GL_SHININESS, 50)
	else
		glColor3f(self.r, self.g, self.b)
	end
  end
end

module Aims
    
    class Atom
  
	  @@black = nil
	  @@white = nil
      @@blue = nil
      @@red = nil
      @@green = nil
      @@dark = nil
      @@light = nil
	  @@yellow = nil
  
      def material
	    unless @@yellow
			@@yellow = Material.new(1,1,0,1)
		end
		
	    unless @@black
		  @@lback = Material.new(0,0,0,1)
		end
        
		unless @@white
		  @@lback = Material.new(1,1,1,1)
		end
        
		unless @@blue
          @@blue = Material.new(0,0,1,1)
        end
    
        unless @@red
          @@red = Material.new(1,0.4,0.4,1)
        end
    
        unless @@green
          @@green = Material.new(0,1,0,1)
        end
    
        unless @@dark
          @@dark =  Material.new(0.2,0.2,0.2,1)
        end
    
        unless @@light
          @@light = Material.new(1,1,1,1)
        end
    
        case self.species
        when /Ga/
          @@dark
        when /As/
          @@light
        when /In/
          @@green
		when /Si/
		  @@yellow
		when /C/
		  @@red
		else 
		  @@blue
        end
      end
    end

end