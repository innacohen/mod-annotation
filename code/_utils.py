# === Core Libraries ===
import os
import sys
import re
import json
import ast
import pickle
import random
import zipfile
import subprocess
import logging
from pathlib import Path
from datetime import datetime
from urllib.parse import urlparse, parse_qs, urljoin

# === Data Handling ===
import pandas as pd
import numpy as np

# === Visualization ===
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.patches import Patch
import matplotlib.colors as mcolors
from plotnine import *

# === Web & API Utilities ===
import requests
from bs4 import BeautifulSoup
from tqdm import tqdm

# === Modeling & Preprocessing ===
import xgboost as xgb
import shap

from sklearn.pipeline import Pipeline
from sklearn.model_selection import (
    train_test_split,
    RepeatedStratifiedKFold,
    KFold,
    cross_val_score
)
from sklearn.preprocessing import (
    LabelEncoder,
    MultiLabelBinarizer,
    MinMaxScaler
)
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

from sklearn.preprocessing import LabelEncoder


# === Feature Engineering ===
from feature_engine.imputation import (
    AddMissingIndicator,
    ArbitraryNumberImputer,
    MeanMedianImputer,
    CategoricalImputer
)
from feature_engine.selection import (
    DropConstantFeatures,
    DropDuplicateFeatures,
    SmartCorrelatedSelection,
    DropFeatures
)
from feature_engine.encoding import (
    OneHotEncoder,
    RareLabelEncoder
)
from feature_engine.outliers import Winsorizer
from feature_engine.discretisation import DecisionTreeDiscretiser
from feature_engine.wrappers import SklearnTransformerWrapper

# === Pandas Display Settings ===
pd.set_option("display.max_columns", None)


# === Global Variables ===

PROJECT_DIR = Path(__file__).parent.parent
CODE_DIR = PROJECT_DIR / "code"
DATA_DIR = PROJECT_DIR / "data"
GPT_DIR = DATA_DIR / "gpt"
RAW_DATA_DIR = DATA_DIR / "raw"
PIPELINE_DATA_DIR = DATA_DIR / "pipeline"
JSON_FP = RAW_DATA_DIR / "model_db_metadata.json"
DROPBOX_DIR = RAW_DATA_DIR / "dropbox"
COMPILED_DIR = RAW_DATA_DIR / "dropbox_compiled"
NMODL_DIR = RAW_DATA_DIR / "nmodl"
SIM_CSV_DIR = RAW_DATA_DIR / "sim_csvs"
SIM_PLOT_DIR = RAW_DATA_DIR / "sim_plots"
CLEAN_DATA_DIR = DATA_DIR / "clean"
ANNOTATIONS_DIR = PROJECT_DIR / "annotations"
ANNOTATIONS_FP = ANNOTATIONS_DIR /"model_db_annotations.xlsx"
GPT_FP = RAW_DATA_DIR / "mod_files_gpt.csv"
LOGS_DIR = PROJECT_DIR / "logs"
OUTPUT_DIR = PROJECT_DIR / "output"
FIGURES_DIR = PROJECT_DIR / "figures"



def View(df, rows=None, cols=None, width=None):
    
    """Displays the first `rows` of the DataFrame like R's View() by adjusting Pandas settings."""
    
    # Show only the first `rows` of the DataFrame
    with pd.option_context(
        "display.max_rows", rows,  # Limit number of rows shown
        "display.max_columns", cols,  # Show all columns
        "display.max_colwidth", width,  # Show full column width
        "display.expand_frame_repr", False  # Prevent column wrapping
    ):
        display(df.head(rows))  # Show only the first `rows`



class DataLogger:
    def __init__(self):
        self.log_df = pd.DataFrame(columns=["step", "n_row", "n_hash"])

    def add_entry(self, step_name, data):
        new_row = {
            "step": step_name,
            "n_row": len(data),
            "n_hash": data["file_hash"].nunique(dropna=True)
        }
        self.log_df = pd.concat(
            [self.log_df, pd.DataFrame([new_row])],
            ignore_index=True
        )

    def get_log(self):
        return self.log_df.copy()