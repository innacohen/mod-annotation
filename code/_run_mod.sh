#!/bin/bash
#SBATCH -J mod-files
#SBATCH -t 03:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs/slurm%j.out

# Create logs directory if it doesn't exist
mkdir -p /nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs

# Load required modules
module purge
module load miniconda
conda activate mod-annotation
python 0-1download_json.py
python 0-2download_nmodl_and_inc.py
python 0-3compile.py
#python 0-4check_compile.py
python 0-5simulate.py
