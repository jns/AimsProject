
require 'fileutils'

#
# A calculation is a combination of a geometry, a control file, and an output
# Each calculation runs in its own directory
# A special file named .calc_status in the calculation directory reveals the status of the calculation
# The format of this file is still under consideration.
# possible options are:
#  • A single word indicating the status
#  • A single word on the first line and unstructured text following (for comments, history, errors)
#  • YAML
#
# The calculation progresses through the following state machine
#   STAGED:
#       This is the initial stage, before the calculation has been 
#       moved to the computation server and queued for execution. 
#       Valid inputs are CANCEL, ENQUEUE
#   QUEUED:
#       Calculation is uploaded to computation server and queued for execution.
#       Valid inputs are CANCEL, PROGRESS
#   RUNNING:
#       Calculation is in progress.
#       Valid inputs are CANCEL
#   COMPLETE:
#       Calculation is completed
#       No valid inputs
#   ABORTED:
module AimsProject

  class Calculation

    attr_accessor :geometry, :control, :status

    # Find all calculations in the current directory 
    # with a given status
    def Calculation.find_all(status)
      calculations = Dir.glob File.join(AimsProject::CALCULATION_DIR, "*", AimsProject::CALC_STATUS_FILENAME)
      calculations.collect{|calc_status_file|
        calc_dir = File.dirname(calc_status_file)
        calc = Calculation.load(calc_dir)
        if (status == calc.status)
          calc
        else
          nil
        end
      }.compact
    end
    
    # Load a calculation from the serialized yaml file in the given directory
    def Calculation.load(dir)
      File.open(File.join(dir, AimsProject::CALC_STATUS_FILENAME), 'r') do |f|
        YAML.load(f)
      end
    end
    
    # Create a calculation and the corresponding
    # directory structure given a geometry and a control 
    # This method will search for the files geometry.#{geometry}.in
    # and control.#{control}.in in the project directory, then
    # create a calculation directory that is the merger of those two
    # filenames, and finally copy the geometry and control files into
    # the calculation directory and rename them geometry.in and control.in
    def Calculation.create(geometry, control)

      calc = Calculation.new(geometry, control)
      control_in = calc.control_file
      geometry_in = calc.geometry_file

      raise "Unable to locate #{control_in}" unless File.exists?(control_in) 
      raise "Unable to locate #{geometry_in}" unless File.exists?(geometry_in)

      raise "#{geometry_in} has changed since last use" unless check_version(geometry_in)
      raise "#{control_in} has changed since last use" unless check_version(control_in)

      FileUtils.mkdir calc.calculation_directory
      FileUtils.cp control_in, File.join(calc.calculation_directory, "control.in")
      FileUtils.cp geometry_in, File.join(calc.calculation_directory, "geometry.in")
      calc.status = AimsProject::STAGED
      calc.save
      
      return calc
    end
    
    # Create a new calculation that will restart a geometry relaxation 
    # calculation using the last available geometry.  
    # This method will generate a new file in 
    # the geometry directory with the extension +restartN+, where 
    # N will be incremented if the filename already exists.
    # A new calculation will be created with the new geometry and 
    # the original control.  
    def restart_relaxation
      
      geometry_orig = self.geometry_file
      n = 0
      begin 
        n += 1
        geometry_new = geometry_orig + ".restart#{n}"
      end while File.exist?(geometry_new)
      
      File.open(geometry_new, 'w') do |f|
        f.puts "# Final geometry from #{calculation_directory}"
        f.puts self.geometry_next_step.format_geometry_in
      end
      
      Calculation.create(geometry_new, self.control)
      
    end
    
    # Initialize a new calculation.  Consider using Calculation#create 
    # to generate the directory structure as well.
    def initialize(geometry, control)
      self.geometry = File.basename(geometry)
      self.control = File.basename(control)
    end

    # Serialize this calculation as a yaml file
    def save(dir = nil)
      dir = calculation_directory unless dir
      File.open(File.join(dir, AimsProject::CALC_STATUS_FILENAME), 'w') do |f|
        f.puts YAML.dump(self)
      end
    end
    
    # Reload this calculation from the serialized YAML file
    def reload
      c = Calculation.load(self.calculation_directory)
      self.geometry = c.geometry
      self.control = c.control
      self.status = c.status
      return self
    end

    # Determine the name of the control.in file from the
    # control variable.  
    def control_file
      File.join(AimsProject::CONTROL_DIR, self.control)
    end

    # Determine the name of the geometr.in file from the 
    # geometry variable
    def geometry_file
      File.join(AimsProject::GEOMETRY_DIR, self.geometry)
    end

    # 
    # Check for the existence of a cached version of the input file
    # If it exists, check if the cached version is the same
    # as the working version, and return true if they are, false if they are not.
    # If the cached version does not exist, then cache the working version and return true.  
    def Calculation.check_version(file)
      cache_dir = ".input_cache"
      unless File.exists? cache_dir
        Dir.mkdir cache_dir
        Dir.mkdir File.join(cache_dir, AimsProject::GEOMETRY_DIR)
        Dir.mkdir File.join(cache_dir, AimsProject::CONTROL_DIR)
      end
      
      return false unless File.exists?(file)
      cache_version = File.join(cache_dir, file)
      if File.exists?(cache_version)
        return FileUtils.compare_file(file, cache_version)
      else
        FileUtils.cp_r file, cache_version
        return true
      end

    end

    # The path of this calculation relative to the project
    def relative_path
      calculation_directory
    end
    
    # 
    # Return the directory for this calculation
    #
    def calculation_directory
      File.join AimsProject::CALCULATION_DIR, "#{geometry}.#{control}"
    end

    # Search the calculation directory for the calculation output.
    # If found, parse it and return the Aims::AimsOutput object, otherwise
    # return nil.
    # If multiple output files are found, use the last one in the list
    # when sorted alpha-numerically.  (This is assumed to be the most recent calculation)
    def output(output_pattern = "*output*")
      output_files = Dir.glob(File.join(calculation_directory, output_pattern))
      if output_files.empty?
        nil
      else
        Aims::OutputParser.parse(output_files.last)
      end
    end

    # Parse the calculation output and return the final geometry
    # of this calculation.  Return nil if no output is found.
    def final_geometry
      # ouput is not cached, so we only retrieve it once
      o = self.output
      if o
        o.final_geometry
      else
        nil
      end
    end
    
    # Parse the geometry.in.next_step file in the calculation directory
    # if it exists and return the Aims::UnitCell object or nil
    def geometry_next_step
      g_file = File.join(calculation_directory, "geometry.in.next_step")
      if File.exists?(g_file)
        Aims::GeometryParser.parse(g_file)
      else
        nil
      end
    end
    
  end
end