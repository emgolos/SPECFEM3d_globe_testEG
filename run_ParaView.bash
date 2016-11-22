#!/bin/bash

source /etc/profile.d/modules.sh
module add engaging/ParaView/4.4.0

sbatch go_Para.sh
