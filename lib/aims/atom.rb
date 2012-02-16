
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