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

# =========================================================================
# These variables should NOT be changed unless you are very confident in
# what you are doing. Make sure you understand all the implications of your
# changes if you do decide to muck with these!
# =========================================================================

namespace :aims do 

desc <<-DESC
  Synchronize with the remote computation cluster.
DESC
task :synchronize, :roles => :data_transfer do 
  # Verify this AimsProject can be loaded
  project = AimsProject::Project.load(project_name)

  find_servers(:roles => :data_transfer).each do |s|
    # Upsync to remote directory
    puts "Upsyncing project to #{s}..."
    run_locally "rsync -auvz #{project.full_path} #{s}:#{remote_project_dir}/"

    # Downsync from remote directory
    puts "Retreiving new data from #{s}"
    run_locally "rsync -auvz #{s}:#{remote_project_dir}/#{project.relative_path}/ #{project.full_path}/"
  end
end


desc <<-DESC
Enqueue all staged calculations.  This task will:
1) Generate a script for running aims in the calculation directory
2) Upload that script to the remote server
3) Execute mpi.q with options to generate the .cmd file suitable for qsub
4) Execute qsub with the -notify flag enabled

Example usage: 
cap enqueue -s nodes=32 memory=1024 time=24
DESC
task :enqueue, :roles => :queue_submission do 
  # Verify this AimsProject can be loaded
  project = AimsProject::Project.load(projectName)

  # Generate the aims.sh shell script that will execute 
  # on the remote host
        script =<<-SHELL_SCRIPT
        #!/bin/bash
        
        # Define a function for modifying the status of the calculation        
        function setStatus() {
        	status=$1
        	STATUSFILE=#{AimsProject::CALC_STATUS_FILENAME}
        	TMPFILE=#{AimsProject::CALC_STATUS_FILENAME}.tmp
        	sed "s/status: .*/status: ${status}/" $STATUSFILE > $TMPFILE
        	mv $TMPFILE $STATUSFILE
        }

        # Setup environment
        export OMP_NUM_THREADS=#{project.omp_num_threads || 1}
        export MKL_NUM_THREADS=#{project.mkl_num_threads || 1}
        export MKL_DYNAMIC=#{project.mkl_dynamic || FALSE}
        export LD_LIBRARY_PATH=#{project.ld_library_path}:$LD_LIBRARY_PATH

        # setup traps for early program termination
        # qsub will send SIGUSR1(30) or SIGUSR2(31) before killing a job
        trap 'setStatus "#{AimsProject::ABORTED}"; exit;' 2 15 30 31
        
        # Set the status to running
        setStatus "#{AimsProject::RUNNING}"
        
        # Run aims
        #{project.aims_path}/#{project.aims_exe}

        # Set the status to complete
        setStatus "#{AimsProject::COMPLETE}"
        
  SHELL_SCRIPT
  

  project.calculations.find_all{|calc| 
    calc.status == AimsProject::STAGED}.each do |calc|

      # Define the remote calculation directory
      remote_calc_dir = "#{project.remote_project_root_dir}/#{project.relative_path}/#{calc.relative_path}"

      # Upload the aims.sh script to the calculation directory
      upload script, remote_calc_dir + "/aims.sh"

      # Define the execution parameters from configuration variables
      # based in on the command line
      n = if configuration[:nodes] 
        configuration[:nodes]
      else
        puts "# of nodes not specified. Default is 8"
        8
      end
      
      d = if configuration[:memory] 
        configuration[:memory]
      else
        puts "Memory/node not specified. Default is 1024"
        1024
      end

      if configuration[:time] 
        configuration[:time]
      else
        puts "Time limit not specified. Default is 24h"
        24
      end
      
      
      run <<-CMD
      cd #{remote_calc_dir};
      mpi.q -n #{n} -d #{d} -t #{d} -ns -k -o $CWD aims.sh";
      echo "qsub -notify aims.sh"
      CMD
  
      calc.status = AimsProject::QUEUED
      calc.save
      
    end
  end
end

