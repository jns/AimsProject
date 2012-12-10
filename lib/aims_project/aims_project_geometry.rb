module AimsProject
  
  # A class that encapsulates the Aims::Geometry and other
  # state information important for AimsProject
  class AimsProjectGeometry
    
    # Boolean flag indicating whether the atoms should be displaced to all lie
    # within the unit cell
    attr_accessor :correct_geometry

    # The filename defining this geometry
    attr_reader :filename
    
    def initialize(file)
      @filename = file
      @geometry_original = Aims::GeometryParser.parse(@filename)
    end
    
    def geometry
      if self.correct_geometry
        geometry_corrected
      else
        geometry_original
      end
    end
    
    def geometry_corrected
      if @geometry_corrected.nil?
        @geometry_corrected = @geometry_original.correct
      end
      @geometry_corrected
    end
    
    def geometry_original
      @geometry_original
    end
    
    def to_s
      @filename
    end
    
    
    def save
      unless @filename
        raise InvalidFilenameException
      end
      raise "AimsProjectGeometry.save is not yet implemented"
    end
    
  end
  
end