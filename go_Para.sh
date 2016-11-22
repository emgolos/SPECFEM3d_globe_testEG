#!/bin/bash

#SBATCH -p sched_mit_redwine


srun --x11=first --pty --mem=48MB paraview
