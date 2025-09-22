# === Core Libraries ===
import os
import sys
import re
import json
import ast
import pickle
import random
from pathlib import Path

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


# Set up credentials and connect to Google Sheets
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
creds = ServiceAccountCredentials.from_json_keyfile_name("gsheet-creds.json", scope)
client = gspread.authorize(creds)
