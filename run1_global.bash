#!/bin/bash



my_local_path=`grep LOCAL_PATH DATA/Par_file | cut -d '=' -f 2`
OUTDIR=./SEM

d=`date` echo "Starting compilation $d"
source /etc/profile.d/modules.sh
module del gcc/4.8.4
module add engaging/openmpi/1.8.8

make clean
make meshfem3D
make create_header_file
./bin/xcreate_header_file
make specfem3D
d=`date`
echo "Finished compilation $d"

# Compute number of nodes needed
NPROC_XI=`grep NPROC_XI DATA/Par_file | cut -c 34- `
NPROC_ETA=`grep NPROC_ETA DATA/Par_file | cut -c 34- `
NCHUNKS=`grep NCHUNKS DATA/Par_file | cut -c 34- `
# total number of nodes is the product of the values read
numnodes=$(( $NCHUNKS * $NPROC_XI * $NPROC_ETA ))

echo "Submitting job"

echo NCHUNKS = $NCHUNKS
echo NPROC_XI = $NPROC_XI
echo NPROC_ETA = $NPROC_ETA
echo " "
echo starting MPI solver on $numnodes processors
echo " "
echo starting run in current directory $PWD
echo " "
echo mesh files will be read from directory $my_local_path
echo " "
echo Output directory is $OUTDIR

sbatch -n $numnodes go_mesher_solver.sh

#sbatch -n $numnodes go_solver.sh


if [ ! -d $OUTDIR ]; then
   mkdir $OUTDIR;
fi
cd $OUTDIR
cp ../DATA/CMTSOLUTION .
cp ../DATA/STATIONS .
cp ../DATA/Par_file .


