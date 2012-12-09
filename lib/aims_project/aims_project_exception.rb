
module AimsProject
  class AimsProjectException < StandardError
  end

  class InvalidFilenameException < AimsProjectException
    def initialize(filename)
      if filename.nil?
        super "No filename specified"
      else
        super "The filename #{filename} is invalid."
      end
    end
  end
  
  class ObjectFileNotFoundException < AimsProjectException
    def initialize(filename)
      super "The serialized yaml file was not found: #{filename}"
    end
  end
  
  class CorruptObjectFileException < AimsProjectException
    def initialize(filename)
      super "The serialized yaml file is corrupt: #{filename}"
    end
  end
  
end