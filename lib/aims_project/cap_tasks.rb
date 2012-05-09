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
  Synchronize with the computation server
DESC
task :synchronize do 
  # Verify this AimsProject can be loaded
  project = AimsProject::Project.load(projectName)
  
  # Upsync to remote directory
  puts "Upsyncing project to remote host..."
  run_locally "rsync -auvz #{project.full_path} #{remote_user}@#{remote_host}:#{remote_project_dir}"

  # Downsync from remote directory
  puts "Retreiving new data from remote host"
  run_locally "rysnc -auvz #{remote_user}@#{remote_host}:#{remote_project_dir}/ #{project.full_path}"

end

task :stage do 
  # Verify this AimsProject can be loaded
  project = AimsProject::Project.load(projectName)

        script =<<-SHELL_SCRIPT
        AIMS_EXE=#{project.aims_exe}
        AIMS_PATH=#{project.aims_path}
        LOCAL_EXE=run_aims.sh
        cat <<EOF > $LOCAL_EXE
        #!/bin/bash
        export OMP_NUM_THREADS=1
        export MKL_NUM_THREADS=1
        export MKL_DYNAMIC=FALSE
        LAPACKBLAS=/u/local/intel/11.1/openmpi/1.4.2/lib:/u/local/compilers/intel/11.0/current/mkl/lib/em64t:/u/local/compilers/intel/11.0/current/lib/intel64
        SCALAPACK=/u/local/apps/scalapack/current:/u/local/apps/blas/00-intel:/u/local/apps/lapack/3.2.1-intel
        export LD_LIBRARY_PATH=$LAPACKBLAS:$SCALAPACK:$LD_LIBRARY_PATH
        $AIMS_PATH/$AIMS_EXE
        EOF
        chmod 755 $LOCAL_EXE

        CWD=`pwd`
        n=$1
        if [ -z $n ]; then
          n=8
          echo "Nodes not specified. Default is 8"
        fi

        d=$2
        if [ -z $d ]; then
          d=1024
          echo "Memory not specified. Default is 1024"
        fi

        t=$3
        if [ -z $t ]; then
          t=24
          echo "Time not specified. Default is 24"
        fi

        mpi.q -n $n -d $d -t $t -ns -k -o $CWD $LOCAL_EXE
        #sed -e 's/pe dc_/pe 8threads/' ${LOCAL_EXE}.cmd > ${LOCAL_EXE}.cmd.tmp
        #mv ${LOCAL_EXE}.cmd.tmp ${LOCAL_EXE}.cmd

  SHELL_SCRIPT
  
end

desc <<-DESC
Enqueue all staged calculations.  This task will upload the calculations
to the remote project dir and submit them to the queue using  
DESC
task :enqueue, :hosts => "jns@hoffman2" do 
  calculations = Dir["*/#{calc_status_filename}"]
  calculations.each do |calc|

    status = get_status(calc)
    calc_dir = File.dirname(calc)

    if status == staged
      upload calc_dir, File.join(remote_project_dir, calc_dir)
      set_status(calc, queued)
      run qsub
    end
  end
end

