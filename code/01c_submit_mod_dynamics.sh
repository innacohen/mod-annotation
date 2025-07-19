#!/bin/bash
#SBATCH -J mod-files
#SBATCH -t 00:30:00
#SBATCH --mail-type=ALL


module purge
module load miniconda
conda activate nn
bash 01b_run_mod_dynamics.sh

