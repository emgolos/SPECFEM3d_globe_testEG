#!/bin/bash
#
#SBATCH --job-name=MESH_run1
#SBATCH --output=Mesher_solver_out.txt
#SBATCH -p sched_mit_redwine


BASEMPIDIR=`grep ^LOCAL_PATH DATA/Par_file | cut -d = -f 2 `

# script to run the mesher and the solver
# read DATA/Par_file to get information about the run
# compute total number of nodes needed
NPROC_XI=`grep ^NPROC_XI DATA/Par_file | cut -d = -f 2 `
NPROC_ETA=`grep ^NPROC_ETA DATA/Par_file | cut -d = -f 2`
NCHUNKS=`grep ^NCHUNKS DATA/Par_file | cut -d = -f 2 `

# total number of nodes is the product of the values read
numnodes=$(( $NCHUNKS * $NPROC_XI * $NPROC_ETA ))

mkdir -p OUTPUT_FILES

# backup files used for this simulation
cp DATA/Par_file OUTPUT_FILES/
cp DATA/STATIONS OUTPUT_FILES/
cp DATA/CMTSOLUTION OUTPUT_FILES/

##
## mesh generation
##
sleep 2

echo
echo `date`
echo "starting MPI mesher on $numnodes processors"
echo


source /etc/profile.d/modules.sh
module add engaging/openmpi/1.8.8
mpirun --mca btl ^scif /nobackup1/emgolos/specfem3d_globe/bin/xmeshfem3D

# checks exit code
if [[ $? -ne 0 ]]; then exit 1; fi

echo "  mesher done: `date`"
echo

# backup important files addressing.txt and list*.txt
cp OUTPUT_FILES/*.txt $BASEMPIDIR/

##
## forward simulation
##


sleep 2

echo
echo `date`
echo starting run in current directory $PWD
echo

mpirun --mca btl ^scif -np $numnodes /nobackup1/emgolos/specfem3d_globe/bin/xspecfem3D

# checks exit code
if [[ $? -ne 0 ]]; then exit 1; fi

echo "finished successfully"
echo `date`

