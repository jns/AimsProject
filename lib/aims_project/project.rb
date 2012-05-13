require 'fileutils'

module AimsProject
  
class Project

      #  A project is a collection of calculations
      #  and tools for managing the execution and analysis of the calculations

      # The name of this project
      attr_accessor :name


      # Load a Project from the serialized yaml file
      def Project.load(filename)
        yamlfile = [filename, filename+".yaml"].find{|f| File.exists?(f)}
        
        File.open(yamlfile, 'r') do |f|
          YAML.load(f)
        end
      end

      # Create a new Project with the given name
      # This will also create the directory structure 
      # for the project.  Returns true if successful, false otherwise
      def Project.create(name)
            p = Project.new
            p.name = name
            
            # Create the project directory
            FileUtils.mkdir(p.relative_path)
            p.save(p.relative_path)
            
            # Create the config directory
            FileUtils.mkdir(File.join(p.relative_path, "config"))
            
            # Create the geometry directory
            FileUtils.mkdir(File.join(p.relative_path, AimsProject::GEOMETRY_DIR))
            
            # Create the control directory
            FileUtils.mkdir(File.join(p.relative_path, AimsProject::CONTROL_DIR))
            
            # Create the calculations directory
            FileUtils.mkdir(File.join(p.relative_path, AimsProject::CALCULATION_DIR))

            return p
      end
      
      # The path of this project relative to project_root_dir
      def relative_path
        name
      end
      
      # The filename of the serialized yaml file representing this project
      def serialized_filename
        "#{self.name}.yaml"
      end
      
      # The full path to this project locally
      def full_path
        File.dirname(File.expand_path(serialized_filename))
      end
            
      # Serialize this project to a yaml file named after this project
      # in the given directory
      def save(dir = ".")
        File.open(File.join(dir, "#{name}.yaml"), 'w') do |f|
          f.print YAML.dump(self)
        end
      end
      
      # Retreive the calcluations managed by this project.
      # This array is loaded directly from serialized yaml
      # files in each calculation directory
      def calculations
        calc_status_files = Dir.glob(File.join(AimsProject::CALCULATION_DIR, "*", AimsProject::CALC_STATUS_FILENAME))
        calc_status_files.collect{|f|
          Calculation.load(File.dirname(f))
        }
      end
      
end
end