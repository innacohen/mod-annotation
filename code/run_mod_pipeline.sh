#!/bin/bash
#SBATCH -J mod-files
#SBATCH -t 00:50:00
#SBATCH --mail-type=ALL
#SBATCH --output=/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs/mod_pipeline_%j.out
#SBATCH --error=/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs/mod_pipeline_%j.err

# Create logs directory if it doesn't exist
mkdir -p /nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs

# Load required modules
module purge
module load miniconda
conda activate mod-annotation

# Run compilation script
bash compile_nmodl.sh
