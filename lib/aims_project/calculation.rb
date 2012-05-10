
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
      calculations = Dir["*/#{AimsProject::CALC_STATUS_FILENAME}"]
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
    
    # Initialize a new calculation.  Consider using Calculation#create 
    # to generate the directory structure as well.
    def initialize(geometry, control)
      self.geometry = geometry
      self.control = control
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
      "control.#{self.control}.in"
    end

    # Determine the name of the geometr.in file from the 
    # geometry variable
    def geometry_file
      "geometry.#{self.geometry}.in"
    end

    # 
    # Check for the existence of a cached version of the input file
    # If it exists, check if the cached version is the same
    # as the working version, and return true if they are, false if they are not.
    # If the cached version does not exist, then cache the working version and return true.  
    def Calculation.check_version(file)
      cache_dir = ".input_cache"
      unless Dir.exists? cache_dir
        Dir.mkdir cache_dir
      end

      cache_version = File.join(cache_dir, file)
      return false unless File.exists?(file)
      if File.exists?(cache_version)
        return FileUtils.compare_file(file, cache_version)
      else
        FileUtils.cp file, cache_version
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
      "#{geometry}.#{control}"
    end

    #
    # Build the calculation by staging the control and geometry files in a unique directory
    # 1) Check that the input files exist
    # 2) Verify that the input files match the cached version
    # 3) Create the calculation directory
    # 4) Copy the geometry and control files into the directory and name them control.in and geometry.in
    # 5) Generate the shell script for calculation execution
    # 6) Set the .calc_status flag to STAGED
    def build_calculation

      control_in = control_file
      geometry_in = geometry_file

      raise "Unable to locate #{control_in}" unless File.exists?(control_in) 
      raise "Unable to locate #{geometry_in}" unless File.exists?(geometry_in)

      raise "#{geometry_in} has changed since last use" unless check_version(geometry_in)
      raise "#{control_in} has changed since last use" unless check_version(control_in)

      FileUtils.mkdir calculation_directory
      FileUtils.cp control_in, File.join(calculation_directory, "control.in")
      FileUtils.cp geometry_in, File.join(calculation_directory, "geometry.in")
      File.open(File.join(calculation_directory, ".calc_status"), "w") do |f|
        f.puts "STAGED"
      end
      puts "Created #{calc_dir} ..."
    end

    # Upload the calculation to the 
    # remote server
    def upload_calculation(ssh)
      
    end

    # Queue the calculation for computation
    def enqueue
    end

    # Test if the calculation is running
    def running?
    end

    # Test if the calculation is complete
    def complete?
    end
    


  end
end