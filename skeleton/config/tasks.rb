require 'stringio'

# ====================================================
# These are capistrano tasks to help with queueing calculations
# on a remote computing-cluster, tracking their status
# and retreiving calculation outputs.
# ====================================================

def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

# logs the command then executes it locally.
# returns the command output as a string
def run_locally(cmd)
  logger.trace "executing locally: #{cmd.inspect}" if logger
  output_on_stdout = nil
  elapsed = Benchmark.realtime do
    output_on_stdout = `#{cmd}`
  end
  if $?.to_i > 0 # $? is command exit code (posix style)
    raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
  end
  logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
  output_on_stdout
end
  
# =========================================================================
# These variables must be set in the client Capfile. Failure to set them 
# will result in an error.
# =========================================================================
_cset(:project_name) {abort "Please specify the project name, set :project_name, 'foo'"}
_cset(:remote_project_dir) {abort "Please specify the name of the remote directory for this project, set :remote_project_dir, 'foo'"}
# _cset(:staging_dir) {}
# _cset(:qsub) {abort "Please specify the queue submission script to use for each calculation, set :qsub, 'foo'"}

# =========================================================================
# These variables may be set in the client capfile if their default values
# are not sufficient.
# =========================================================================
_cset :aims_script, "aims.sh"

# =========================================================================
# These variables should NOT be changed unless you are very confident in
# what you are doing. Make sure you understand all the implications of your
# changes if you do decide to muck with these!
# =========================================================================

  namespace :aims do 

    desc <<-DESC
    Up-sync project with data transfer server
    DESC
    task :upsync, :roles => :data_transfer do 
      # Verify this AimsProject can be loaded
      project = AimsProject::Project.load(project_name)
      find_servers(:roles => :data_transfer).each do |s|
        # Upsync to remote directory
        puts "Upsyncing project to #{s}..."
        run_locally "rsync -auvz #{project.full_path} #{s}:#{remote_project_dir}/"
      end
    end
    
    desc <<-DESC
    Down-sync project with data transfer server
    DESC
    task :downsync, :roles => :data_transfer do
      # Verify this AimsProject can be loaded
      project = AimsProject::Project.load(project_name)

      find_servers(:roles => :data_transfer).each do |s|
        # Downsync from remote directory
        puts "Retreiving new data from #{s}"
        run_locally "rsync -auvz #{s}:#{remote_project_dir}/#{project.relative_path}/ #{project.full_path}/"
      end      
    end

    desc <<-DESC
    Synchronize with the remote computation cluster.
    DESC
    task :synchronize, :roles => :data_transfer do 
      # Verify this AimsProject can be loaded
      project = AimsProject::Project.load(project_name)
      upsync
      downsync
    end

    task :env, :roles => :queue_submission do 
      run "env"
    end
    
    task :qstat, :roles => :queue_submission do
      find_servers(:roles => :queue_submission).each do |s|
        # Upsync to remote directory
        stream qstat_cmd
      end
      
    end

    desc <<-DESC
    Enqueue all staged calculations.  
    This task will:
    1) Customize and upload the script aims.sh to the remote server
    2) cd to the calculation directory on the remote host
    3) execute the "qsub" command as defined in Capfile
    
    Example usage: 
    cap aims:enqueue 
    DESC
    task :enqueue, :roles => :queue_submission do 
      
      #  Load the project
      project = AimsProject::Project.load(project_name)

      # Enqueue all staged calculations
      project.calculations.find_all{|calc| 
        calc.status == AimsProject::STAGED
        }.each do |calc|

          # Define the remote calculation directory
          remote_calc_dir = "#{remote_project_dir}/#{project.relative_path}/#{calc.relative_path}"

          # Upload the aims.sh script to the calculation directory
          upload File.join(AimsProject::CONFIG_DIR, aims_script), File.join(remote_calc_dir, aims_script) 


          run <<-CMD
          cd #{remote_calc_dir};
          #{qsub}
          CMD

          # TODO, do this first, and then revert inside rollback
          calc.status = AimsProject::QUEUED
          calc.save

        end
      end

    end
