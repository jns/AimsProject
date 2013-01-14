require 'erb'
require 'observer'

module AimsProject
  # The geometry model utilized by this application
  class GeometryFile 
  
    include Observable
    
    # Include Aims here to ensure that ERB will evaluate ruby
    # without prefixing Aims:: when using the builtin binding.
    include Aims
  
    # Read and parse a geometry file.  Use the given binding to 
    # evaluate any embedded ruby
    def GeometryFile.eval_geometry(str, _binding=nil)

      b = if _binding
        _binding
      else
        binding()
      end

      erb = ERB.new(str)
      erb.result(b)

    end
  
    # The filename of the geometry file
    attr_reader :file
    
    # The Aims::Geometry object
    attr_reader :aims_geometry
    
    # The string representation of the parsed input geometry
    attr_reader :input_geometry
    
    # The raw unevaluated input.
    attr_reader :raw_input

    # Parse a geometry input 
    # Evaluate any embedded ruby using the given binding
    # @param input If input is a File, the file is read and evaluated with ERB
    #             If input is a String, the input is directly evaluated with ERB
    # @param _binding The binding to use when evaluating with EB
    def initialize(input, _binding=nil)
      
      if input.respond_to? :read
        @file = input
        @raw_input = @file.read
      elsif input.is_a? String
        @raw_input = input
      elsif input.is_a? Aims::Geometry
        @aims_geometry = input
        @input_geometry = @aims_geometry.format_geometry_in
        @raw_input = @input_geometry
      end
      
      begin
        # Attempt to evaluate the raw input, but don't require it.
        @binding = _binding
        evaluate(@binding)
      rescue
      end
    end
    
    # Set the raw input
    # @param str The string to set the raw input to
    # @param notify Whether or not to notify observer. Set this to false if you intend to call evaluate immediately after
    def raw_input=(str, notify = true)
      @raw_input = str
      if notify
        changed
        notify_observers
      end
    end
    
    # Evaluate the raw input and return a geometry String formatted in the Aims geometry.in format
    # 
    def evaluate(_binding=nil)
      if _binding
        @binding = _binding
      end
      
      @input_geometry = GeometryFile.eval_geometry(@raw_input, @binding)
      @aims_geometry = GeometryParser.parse_string(@input_geometry) 
      
      changed
      notify_observers
      
      @aims_geometry
    end
    
    # Delegate calls to the Aims::Geometry object if it exists.
    def method_missing(symbol, *args, &block)
      if @aims_geometry.nil?
        raise GeometryEvaluationException.new
      else
        @aims_geometry.send(symbol, *args, &block)
      end
    end
    
    # Check the consistency between the raw, the evaluated and the object-space geometries
    def is_valid?
      begin
        validate
        return true
      rescue GeometryValidationException => e
        return false
      end
    end
      
    # Check the consistency of all internal data models
    # @return true, otherwise raises a GeoemtryValidationException
      def validate
        # The raw input evaluated must match the input_geometry
        erb = ERB.new(@raw_input)
        res = erb.result(@binding)
        unless  res == @input_geometry
          raise GeometryValidationException.new("raw input doesn't match evaluated input")
        end
      
        # Also need to somehow validate against the Aims::Geometry
        g = GeometryParser.parse_string(res)
        unless g.atoms.size == @aims_geometry.atoms.size
          raise GeometryValidationException("input geometry atom count doesn't match aims_geometry")
        end
        
        unless g.lattice_vectors.size == @aims_geometry.lattice_vectors.size
          raise GeometryValidationException("input geometry lattice vector count doesn't match aims_geometry")
        end
      
        g.atoms.each{|a| 
          unless @aims_geometry.atoms.member?(a)
            raise GeometryValidationException("atom mismatch")
          end
        }
        
        g.lattice_vectors.each{|v| 
          unless @aims_geometry.lattice_vectors.member?(v)
            raise GeometryValidationException("lattice vector mismatch")
          end
        }

        return true
    end
    
    # Save this geometry 
    # raises an InvalidFilenameException unless @file is not nil
    # @return  self
    def save
      save_as(@file)
    end
        
    # Save the raw input to file if it passes validation
    # raises an InvalidFilenameException unless @file is not nil
    # raises a GeometryValidationException if it fails to pass Validation
    # @return A new GeometryFile object representing the geometry in the newly created file
    #         or this GeometryFile object if file = nil
    def save_as(file)

        if file.nil?
          raise InvalidFilenameException(nil) unless @file
          file = @file
        end
        
        validate
        
        File.open(file, 'w') {|f|
          f.write @raw_input
        }
        
        if file == @file
          return self
        else
          GeometryFile.new(File.new(file.path, "r"))
        end
        
    end
    
  end
  
  
end