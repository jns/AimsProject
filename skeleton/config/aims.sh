#!/bin/bash

# Setup environment
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export MKL_DYNAMIC=FALSE

export LD_LIBRARY_PATH=/u/local/compilers/intel/11.1/073/mkl/lib/em64t:/u/local/compilers/intel/11.1/073//lib/intel64:/u/local/compilers/intel/11.1/073/ipp/em64t/sharedlib:/u/local/compilers/intel/11.1/073/mkl/lib/em64t:/u/local/compilers/intel/11.1/073/tbb/intel64/cc4.1.0_libc2.4_kernel2.6.16.21/lib:/u/local/apps/scalapack/current/ib:/u/local/compilers/intel/11.0/current/mkl/lib/em64t/:/u/local/intel/11.1/openmpi/1.4.5/lib:/u/local/compilers/intel/11.1/080/mkl/lib/em64t:/u/local/compilers/intel/11.1/080/lib/intel64

STATUSFILE=calc_status.yaml
LOCKFILE=${STATUSFILE}.lock
MACHINEFILE=hfile

# Required by openmpi
source /u/local/Modules/default/init/modules.sh
module load intel/11.1
module load openmpi/1.4


# Set the jobid in the status file
function setJobID() {
	if [ ! -f $LOCKFILE ]; then
		touch $LOCKFILE;
		echo "jobid: ${JOB_ID}" >> $STATUSFILE
		rm $LOCKFILE;
	fi
}

# Define a function for modifying the status of the calculation        
function setStatus() {
        if [ ! -f $LOCKFILE ]; then
                touch $LOCKFILE;
        status=$1;
        date_str=`date +'%Y-%m-%d %T %:z'`
        TMPFILE=calc_status.tmp;
        sed "s/status: .*/status: ${status}/; s/updated_at: .*/updated_at: ${date_str}/" $STATUSFILE > $TMPFILE;
        mv $TMPFILE $STATUSFILE;
                rm $LOCKFILE;
        fi
}



# setup traps for early program termination
# qsub with the -notify flag will send SIGUSR1(30) or SIGUSR2(31) before killing a job
trap 'setStatus "ABORTED"; exit;' SIGUSR1 SIGUSR2

# Set the status to running
setJobID
setStatus "RUNNING"

# Run aims
# $NSLOTS is set by the sun-grid-engine when qsub is invoked. 
awk '{print $1 " slots=" $2}' $PE_HOSTFILE > $MACHINEFILE
mpiexec -n $NSLOTS -machinefile $MACHINEFILE $HOME/bin/aims.071711_6.scalapack.mpi.x

# Set the status to complete
setStatus "COMPLETE"
