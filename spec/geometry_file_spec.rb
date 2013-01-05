require 'aims_project'
require 'tempfile'
include AimsProject
require 'erb'
describe GeometryFile do

  specProject = Project.new("Spec")

  periodic_2atoms =<<-EOS
  lattice_vector 5.65 0 0
  lattice_vector 0 5.65 0
  lattice_vector 0 0 5.65
  atom 0 0 0 Ga
  atom 2.125 2.125 2.125 As
  EOS

  context "Parsing Geometry Input" do


    it "Should read from a String" do 
      GeometryFile.new(periodic_2atoms)
    end

    it "Should read from a File" do 
      input = File.new(File.join(File.dirname(__FILE__),"geometry.periodic_2atoms.in"))
      GeometryFile.new(input)
    end

  end
  
  context "Delegation" do 
    
    g = GeometryFile.new(periodic_2atoms)
    
    it "Should respond to :atoms" do
      g.atoms.size.should eq(2)      
    end

    it "Should respond to :repeat" do 
      g.repeat(2,2,1).atoms.size.should eq(8)
    end
  end
  context "Evaluating ERB" do
    
    class Stub
      def initialize
        @a = 5.65
      end
      def get_binding
        binding()
      end
    end
      
    it "Should use the given binding to evaluate variables" do
      
      g = GeometryFile.new(<<-'EOS', Stub.new.get_binding)
      lattice_vector <%=@a%> 0 0
      lattice_vector 0 <%= @a %> 0
      lattice_vector 0 0 <%= @a %>
      atom 0 0 0 Ga
      atom <%= [@a/4, @a/4, @a/4].join(" ") %> As      
      EOS
      g.atoms.size.should eq(2)
      g.atoms[0].x.should eq(0)
      g.atoms[1].x.should eq(5.65/4)
    end

    it "Should fail if the binding is missing variables" do

      expect {GeometryFile.new(<<-'EOS', Stub.new.get_binding)}.to raise_error
      lattice_vector <%=@b%> 0 0
      lattice_vector 0 <%= @b %> 0
      lattice_vector 0 0 <%= @b %>
      atom 0 0 0 Ga
      atom <%= [@a/4, @a/4, @a/4].join(" ") %> As
      EOS
    end
  end
    

  
  it "Should raise an error for modifications to erb generated atoms" do
  end
  
  
end