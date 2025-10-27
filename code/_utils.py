# === Core Libraries ===
import os
import sys
import re
import json
import ast
import pickle
import random
from pathlib import Path
import requests
import logging
from datetime import datetime
from urllib.parse import urlparse, parse_qs 
import zipfile
import subprocess

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
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup

# === Google Sheets Integration ===
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from gspread_dataframe import set_with_dataframe

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
RAW_DATA_DIR = DATA_DIR / "raw"
JSON_FP = RAW_DATA_DIR / "model_db_metadata.json"
DROPBOX_DIR = RAW_DATA_DIR / "dropbox"
COMPILED_DIR = RAW_DATA_DIR / "dropbox_compiled"
NMODL_DIR = RAW_DATA_DIR / "nmodl"
SIM_CSV_DIR = RAW_DATA_DIR / "sim_csvs_new"
SIM_PLOT_DIR = RAW_DATA_DIR / "sim_plots_new"
CLEAN_DATA_DIR = DATA_DIR / "clean"
ANNOTATIONS_DIR = PROJECT_DIR / "annotations"
ANNOTATIONS_FP = ANNOTATIONS_DIR /"model_db_annotations.xlsx"
LOGS_DIR = PROJECT_DIR / "logs"
OUTPUT_DIR = PROJECT_DIR / "output"
FIGURES_DIR = PROJECT_DIR / "figures"



