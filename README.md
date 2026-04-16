# Mod-File Subtype Classification & Analysis

This repository contains code, data, and figures for analyzing and classifying ion channel and receptor subtypes from MOD files using machine learning and simulation-derived features.

## Repository Structure

```
├── annotations/ # Dataset (ModelDB annotations and labels)
├── code/ # All scripts and notebooks for data processing, modeling, and figures
├── figures/ # Output figures used in the manuscript
├── README # This file
```


## Folder Details

- **annotations/**
  - Contains the dataset used for training and evaluation.
  - Includes original and processed annotation files (e.g., `model_db_annotations.xlsx`).

- **code/**
  - Contains all scripts used in the pipeline.
  - Files are prefixed with numbers (`0-`, `1-`, `2-`, etc.) indicating approximate execution order.
  - Note: Some scripts are independent and can be run separately.

- **figures/**
  - Contains all generated figures (main + supplemental).
  - Includes Sankey diagrams, panel plots, and performance visualizations.

## Pipeline Overview

The workflow consists of the following major steps:

1. **Data Acquisition & Preparation**
   - `0-download_*.py`
   - Downloads and prepares MOD files and metadata.

2. **Compilation & Simulation**
   - `0-compile.py`, `0-simulate.py`
   - Compiles MOD files and extracts simulation-based features.

3. **Feature Engineering**
   - `_get_mod_dynamics.py`
   - Extracts dynamic features (e.g., time-to-peak, decay metrics).

4. **Modeling & Analysis**
   - `2-ml_pipeline.ipynb`
   - `2-gpt.ipynb`
   - Trains machine learning models and evaluates predictions.

5. **Evaluation & Metrics**
   - `check_labels.R`, `kappa.R`
   - Computes agreement, confusion matrices, and performance metrics.

6. **Visualization**
   - `3-sankey.R`
   - `3-scatterpie.ipynb`
   - `3-heatmap.R`
   - Generates all manuscript figures.

## How to Run

**1. Clone the repository**
```bash
git clone https://github.com/innacohen/mod-annotation.git
cd mod-annotation
```

**2. Set up environment**
Python (recommended: 3.9+)
R (for visualization scripts)

```bash
pip install -r requirements.txt   
```
**3. Run pipeline**
Run scripts in approximate order:
```bash
# Data + preprocessing
python code/0-download_*.py
python code/0-compile.py
python code/0-simulate.py
python code/0-combine.py

# Feature extraction
python code/_get_mod_dynamics.py

# Modeling
jupyter notebook code/2-ml_pipeline.ipynb
```

## Notes
- Some scripts assume specific file paths (e.g., cluster environments). You may need to modify paths locally.
- Intermediate files (e.g, CSV outputs) are reused across steps.
- Not all scripts must be run sequentially. Figure scripts can often be run independently once data is prepared.

## Licence
This project is released under the BSD 3-Clause License, allowing reuse and modification with attribution.

## Acknowledgments
- ModelDB for providing MOD file data
- Python and R open-source libraries used throughout the project
- Portions of the pipeline were developed iteratively with assistance from LLM-based tools (e.g., ChatGPT, Claude) for code structuring and debugging.
  
## Contact
For questions or issues, please open a GitHub issue or contact the repository owner.


