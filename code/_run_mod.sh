#!/bin/bash
#SBATCH -J mod-files
#SBATCH -t 01:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs/mod_pipeline_%j.out
#SBATCH --error=/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs/mod_pipeline_%j.err

# Create logs directory if it doesn't exist
mkdir -p /nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs

# Load required modules
module purge
module load miniconda
conda activate mod-annotation
#python 0-1download_json.py
#python 0-2download_nmodl.py
bash 0-3compile_and_simulate.sh
