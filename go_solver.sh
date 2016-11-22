#!/bin/bash
#
#SBATCH --job-name=SPECFEM3D_run1
#SBATCH --output=specfem3d_run1.txt
#SBATCH -p sched_mit_redwine

source /etc/profile.d/modules.sh
module add engaging/openmpi/1.8.8
mpirun --mca btl ^scif /nobackup1/emgolos/specfem3d_globe/bin/xspecfem3D

