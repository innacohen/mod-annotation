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

# Download python scripts
#CPU Efficiency: 15.93% of 00:01:53 core-walltime
#Job Wall-clock time: 00:01:53
#python 0-1download_json.py
#python 0-2download_nmodl.py

# Compile 
#CPU Efficiency: 61.22% of 00:00:49 core-walltime
#Job Wall-clock time: 00:00:49
#bash 0-3compile_nmodl.sh







