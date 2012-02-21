
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
			@@yellow = AimsProject::Material.new(1,1,0,1)
		end
		
	    unless @@black
		  @@lback = AimsProject::Material.new(0,0,0,1)
		end
        
		unless @@white
		  @@lback = AimsProject::Material.new(1,1,1,1)
		end
        
		unless @@blue
          @@blue = AimsProject::Material.new(0,0,1,1)
        end
    
        unless @@red
          @@red = AimsProject::Material.new(1,0.4,0.4,1)
        end
    
        unless @@green
          @@green = AimsProject::Material.new(0,1,0,1)
        end
    
        unless @@dark
          @@dark =  AimsProject::Material.new(0.2,0.2,0.2,1)
        end
    
        unless @@light
          @@light = AimsProject::Material.new(1,1,1,1)
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