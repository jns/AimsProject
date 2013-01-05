require 'erb'
require 'delegate'

module AimsProject
  # The geometry model utilized by this application
  class GeometryFile < DelegateClass(Aims::Geometry)
  
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
    attr_accessor :file  

    # Boolean maintains whether the atoms are in the packed arrangement or not
    attr_reader :packed
    
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
      
      if input.kind_of? File
        @file = input
        @raw_input = @file.read
        puts @input
      elsif input.is_a? String
        @raw_input = input
      end
      @input_geometry = GeometryFile.eval_geometry(@raw_input, _binding)
      @aims_geometry = GeometryParser.parse_string(self.input_geometry)
      super(@aims_geometry)
    end
  end
  
  
end