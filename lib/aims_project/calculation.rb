
require 'fileutils'
require 'erb'
require 'date'

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

    # The name of the geometry file
    attr_accessor :geometry 
    
    # The name of the control file
    attr_accessor :control 
    
    # The current calculation status
    attr_accessor :status

    # The calculation subdirectory, (can be nil)
    attr_accessor :calc_subdir

    # An array of (#to_s) items that are the calculation history  
    attr_accessor :history

    # Timestamp indicating creation of this calculation
    attr_writer :created_at
    def created_at
      @created_at = cast_as_date(@created_at)
    end
    
    # Timestamp indicating last update of this calculation
    # (currently only updates when saved)
    attr_writer :updated_at
    def updated_at
      # Cast value to Date
      # Do this in the accessor because loading from YAML bypasses the setter method
      @updated_at = cast_as_date(@updated_at)
    end

    def cast_as_date(obj)
      if obj.is_a? Date or obj.is_a? Time or obj.is_a? DateTime
        obj.to_datetime
      elsif obj.is_a? String
        DateTime.parse(obj)
        # unless s
        #   s = DateTime.strptime(obj, "%F %T %z")
        # end
        # unless s
        #   s = DateTime.strptime(obj, "%FT%s%z")
        # end
        # s
      else
        DateTime.new(0)
      end      
    end

    # Find all calculations in the current directory 
    # with a given status
    def Calculation.find_all(status)
      # Catch all root calculations
      calculations = Dir.glob File.join(AimsProject::CALCULATION_DIR, "*", AimsProject::CALC_STATUS_FILENAME)
      # Catch all sub calculations
      calculations << Dir.glob(File.join(AimsProject::CALCULATION_DIR, "*", "*",  AimsProject::CALC_STATUS_FILENAME))
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
    # raises an *ObjectFileNotFoundException* if the specified directory does
    # not contain a yaml serialization of the calculation.
    # raises a *CorruptObjectFileException* if the yaml file cannot be de-serialized
    def Calculation.load(dir)
      
      calc_file  = File.join(dir, AimsProject::CALC_STATUS_FILENAME)
      raise ObjectFileNotFoundException.new(calc_file) unless File.exists?(calc_file)
      
      f = File.open(calc_file, 'r')
      calc_obj = YAML.load(f)
      f.close
      
      raise CorruptObjectFileException.new(calc_file) unless calc_obj
      return calc_obj
    end
    
    # Create a calculation and the corresponding
    # directory structure given a geometry and a control 
    # This method will search for the files geometry.#{geometry}.in
    # and control.#{control}.in in the project directory, then
    # create a calculation directory that is the merger of those two
    # filenames, and finally copy the geometry and control files into
    # the calculation directory and rename them geometry.in and control.in
    # @param [String] geometry The filename of the geometry file to use to initialize the calculation
    # @param [String] control The filename of the control file to use to initialize the calculation
    # @param [Hash<Symbol, Object>] user_vars A symbol=>Object hash of variables that will be available when 
    #                     evaluating the geometry and control files using embedded ruby  
    #                     This hash is also used to generate a calculation subdirectory
    def Calculation.create(project, geometry, control, user_vars = {})

      calc = Calculation.new(geometry, control)
      calc.created_at = Time.new

      control_in = calc.control_file
      geometry_in = calc.geometry_file

      # Define the calculation sub-directory if user_vars exists
      unless user_vars.empty?
        calc.calc_subdir = user_vars.keys.collect{|k| (k.to_s + "=" + user_vars[k].to_s).gsub('@', '').gsub(' ','_') }.join("..")
      end
      
      # Add configuration variables to the calculation binding
      uvars_file = File.join(AimsProject::CONFIG_DIR, "user_variables.rb")
      calc.get_binding.eval(File.read(uvars_file)) if File.exists?(uvars_file)

      # Merge project variables into calcuation binding
      if project
        project.instance_variables.each{|v|
          if v == :@name # Ignore the project name
            calc.instance_variable_set(:@project_name, project.instance_variable_get(v))
          else
            calc.instance_variable_set(v, project.instance_variable_get(v))
          end
        }
      end

      # Merge user-vars to the calculation binding
      user_vars.each_pair{|sym, val|
        calc.instance_variable_set(sym, val)
      }
      

      # Check file existence
      raise "Unable to locate #{control_in}" unless File.exists?(control_in) 
      raise "Unable to locate #{geometry_in}" unless File.exists?(geometry_in)

      # Validate the files
      raise "#{geometry_in} has changed since last use" unless check_version(geometry_in)
      raise "#{control_in} has changed since last use" unless check_version(control_in)

      # Validate that the directory doesn't already exist
      if Dir.exists? calc.calculation_directory
        raise "Could not create calculation.\n #{calc.calculation_directory} already exists. \n\n If you really want to re-create this calculation, then manually delete it and try again. \n"
      end
      FileUtils.mkdir_p calc.calculation_directory
      
      erb = ERB.new(File.read(control_in))
      File.open File.join(calc.calculation_directory, "control.in"), "w" do |f|
        f.puts erb.result(calc.get_binding)
      end
      
      erb = ERB.new(File.read(geometry_in))
      File.open File.join(calc.calculation_directory, "geometry.in"), "w" do |f|
        f.puts erb.result(calc.get_binding)
      end


      calc.status = AimsProject::STAGED
      calc.save
      
      return calc
    end
    
    # Get the binding for this calculation
    def get_binding
      binding()
    end
    
    # The name of this calculation
    def name
      "#{geometry}.#{control}"
    end
    
    # Set the status to HOLD.
    # Only possible if status is currently STAGED
    def hold
      if STAGED == status
        self.status = HOLD
        save
        return true
      else
        return false
      end
    end
    
    # Set the status to STAGED if current status is HOLD
    def release
      if HOLD == status
        self.status = STAGED
        save
        return true
      else
        return false
      end
    end
    
    # Create a new calculation that will restart a geometry relaxation 
    # calculation using the last available geometry.  
    # This method will generate a new file in 
    # the geometry directory with the extension +restartN+, where 
    # N will be incremented if the filename already exists.
    # A new calculation will be created with the new geometry and 
    # the original control.  
    def restart_relaxation
      
      # Create a new geometry file
      geometry_orig = self.geometry_file
      
      # If restarting a restart, then increment the digit
      if (geometry_orig.split(".").last =~ /restart(\d+)/)
        n = $1.to_i
        geometry_orig = geometry_orig.split(".")[0...-1].join(".")
      else
        n = 0
      end

      begin 
        n += 1
        geometry_new = geometry_orig + ".restart#{n}"
      end while File.exist?(geometry_new)
      
      File.open(geometry_new, 'w') do |f|
        f.puts "# Final geometry from #{calculation_directory}"
        f.puts self.geometry_next_step.format_geometry_in
      end
      
      Calculation.create(nil, geometry_new, self.control)
      
    end
    
    # Initialize a new calculation.  Consider using Calculation#create 
    # to generate the directory structure as well.
    # @param [String] geometry the filename of the input geometry
    # @param [String] control the filename of the input control 
    def initialize(geometry, control)
      self.geometry = File.basename(geometry)
      self.control = File.basename(control)
      self.history = Array.new
    end

    # Serialize this calculation as a yaml file
    def save(dir = nil)
      self.updated_at = Time.new
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
      File.join AimsProject::CALCULATION_DIR, self.name, (@calc_subdir || "")
    end

    def load_output(output_pattern = "*output*")
      output_files = Dir.glob(File.join(calculation_directory, output_pattern))
      if output_files.empty?
        @output = nil
      else
        @output = Aims::OutputParser.parse(output_files.last)
      end      
    end

    # Search the calculation directory for the calculation output.
    # If found, parse it and return the Aims::AimsOutput object, otherwise
    # return nil.
    # If multiple output files are found, use the last one in the list
    # when sorted alpha-numerically.  (This is assumed to be the most recent calculation)
    def output(output_pattern = "*output*")
      unless @output
        load_output(output_pattern)
      end
      @output
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
    # if it exists and return the Aims::Geometry object or nil
    def geometry_next_step
      g_file = File.join(calculation_directory, "geometry.in.next_step")
      if File.exists?(g_file)
        Aims::GeometryParser.parse(g_file)
      else
        nil
      end
    end
    
    # Return whether this calculation is converged or not
    def converged?
      output.geometry_converged
    end
    
  end
end