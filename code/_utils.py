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
DATA_DIR = PROJECT_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
JSON_FP = RAW_DATA_DIR / "model_db_metadata.json"
DROPBOX_DIR = RAW_DATA_DIR / "dropbox"
COMPILED_DIR = RAW_DATA_DIR / "dropbox_compiled"
NMODL_DIR = RAW_DATA_DIR / "nmodl"
SIM_DATA_DIR = RAW_DATA_DIR / "sim_csvs"
SIM_PLOT_DIR = RAW_DATA_DIR / "sim_plots"
CLEAN_DATA_DIR = DATA_DIR / "clean"
ANNOTATIONS_DIR = PROJECT_DIR / "annotations"
ANNOTATIONS_FP = ANNOTATIONS_DIR /"model_db_annotations.xlsx"
LOGS_DIR = PROJECT_DIR / "logs"
OUTPUT_DIR = PROJECT_DIR / "output"
FIGURES_DIR = PROJECT_DIR / "figures"




#todo
# Set up credentials and connect to Google Sheets
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
# Use absolute path from project root
creds_path = PROJECT_DIR / "secret" / "gsheet-creds.json"
# Check if the credentials file exists
if not creds_path.exists():
    print(f"Warning: Google Sheets credentials file not found at {creds_path}")
    print("Google Sheets functionality will not be available")
    client = None
else:
    creds = ServiceAccountCredentials.from_json_keyfile_name(str(creds_path), scope)
    client = gspread.authorize(creds)



def plot_countplot(
    df,
    col,
    subset_query=None,
    title=None,
    color='#4C72B0',
    horizontal=True,
    figsize=(8, 5),
    show_counts=False
):
    """
    Create a countplot from a column in a pandas DataFrame.

    Parameters:
    -----------
    df : pandas.DataFrame
        Your input DataFrame.
    col : str
        Column to count and plot.
    subset_query : str, optional
        Optional query string to filter the DataFrame (e.g., "type == 'Neither'").
    title : str, optional
        Title for the plot.
    color : str, optional
        Bar color (default: '#4C72B0').
    horizontal : bool, default True
        If True, plot bars horizontally.
    figsize : tuple, optional
        Figure size in inches.
    show_counts : bool, default False
        If True, annotate bars with counts.
    """
    data = df.query(subset_query) if subset_query else df
    order = data[col].value_counts().index

    plt.figure(figsize=figsize)
    ax = sns.countplot(
        data=data,
        y=col if horizontal else None,
        x=None if horizontal else col,
        order=order,
        color=color
    )

    if show_counts:
        for p in ax.patches:
            count = int(p.get_width() if horizontal else p.get_height())
            pos_x = p.get_width() + 0.5 if horizontal else p.get_x() + p.get_width() / 2
            pos_y = p.get_y() + p.get_height() / 2 if horizontal else p.get_height() + 0.5
            if horizontal:
                ax.text(count + 0.5, p.get_y() + p.get_height()/2, str(count), va='center')
            else:
                ax.text(p.get_x() + p.get_width()/2, count + 0.5, str(count), ha='center')

    ax.set_title(title or f"Count of {col}")
    ax.set_xlabel("Count" if horizontal else col)
    ax.set_ylabel(col if horizontal else "Count")
    ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))
    plt.tight_layout()
    plt.show()

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

# Function to extract mod directory from the URL
def get_dir(url):
    match = re.search(r"file=([^/]+)/[^/]+\.mod", url)  # Extract the directory name before the .mod file
    return match.group(1) if match else None  # Return directory name if found, else None

# Function to extract mod file name without extension
def get_fname(url):
    match = re.search(r"/([^/]+)\.mod$", url)  # Get filename without extension
    return match.group(1) if match else None  # Return only the name (e.g., 'na')

# Function to extract model_id from the URL
def get_model_id(url):
    match = re.search(r"https://modeldb\.science/(\d+)", url)
    return int(match.group(1)) if match else None  # Convert to integer

# Function to extract all TITLE occurrences from .mod content
def get_title(content):
    if pd.isna(content):  
        return None
    matches = re.findall(r"^TITLE\s+([^\n:]+)", content, re.MULTILINE)  # Stop at comments
    return matches if matches else None

# Function to extract all COMMENT sections from .mod content
def get_comment(content):
    if pd.isna(content):  
        return None
    matches = re.findall(r"COMMENT\s+(.*?)(?:\s+ENDCOMMENT|\Z)", content, re.DOTALL)  
    return matches if matches else None

# Function to extract all SUFFIX occurrences from .mod content
def get_suffix(content):
    if pd.isna(content):  
        return None
    matches = re.findall(r"SUFFIX\s+([^\n:\s]+)", content, re.MULTILINE)  # Stop at comments
    return matches if matches else None


def get_use_ion(content):
    """
    Extracts the ion names used in the 'USEION' statements from NEURON mod file content.

    Parameters:
    - content (str): The content of the .mod file.

    Returns:
    - list: A list of ions used in 'USEION' statements, or None if none are found.
    """
    if pd.isna(content):  
        return None
    
    # Find all occurrences of USEION followed by an ion name
    matches = re.findall(r"USEION\s+(\w+)", content, re.MULTILINE)

    return matches if matches else None


# Function to extract all ions listed after READ but stopping before WRITE, USEION, RANGE, GLOBAL, NONSPECIFIC_CURRENT, or VALENCE
def get_read_ion(content):
    if pd.isna(content):  
        return None
    
    matches = re.findall(r"USEION\s+\w+\s+READ\s+([\w,\s]+?)(?=\s+(?:WRITE|USEION|RANGE|GLOBAL|NONSPECIFIC_CURRENT|VALENCE|:|\n|$))", content, re.MULTILINE)

    if not matches:
        return None

    read_ions = [ion.strip() for match in matches for ion in re.split(r"[,\s]+", match) if ion]

    return read_ions if read_ions else None  


# Function to extract all ions listed after WRITE, stopping before VALENCE
def get_write_ion(content):
    if pd.isna(content):  
        return None

    matches = re.findall(r"WRITE\s+([^\n:]+?)(?=\s+(?:VALENCE|:|\n|$))", content, re.MULTILINE)

    if not matches:
        return None

    write_ions = [ion.strip() for match in matches for ion in re.split(r"[,\s]+", match) if ion]

    return write_ions if write_ions else None  


def write_current_yn(ions):
    """
    Checks if mod_write_ion contains an ion that starts with 'i' (indicating a current).

    Args:
        write_ions (list): List of ions written in the mod file.

    Returns:
        int: 1 if any ion starts with 'i', otherwise 0.
    """
    if not ions:  # Handle empty lists or None
        return 0

    return int(any(ion.startswith("i") for ion in ions))


# Function to extract all NONSPECIFIC currents
def get_nonspecific_current(content):
    if pd.isna(content):  
        return None

    matches = re.findall(r"NONSPECIFIC_CURRENT\s+([^\n:]*)", content)

    if not matches:
        return None

    nonspecific_currents = [curr.strip() for match in matches for curr in re.split(r"[,\s]+", match) if curr]

    return nonspecific_currents if nonspecific_currents else None  

#todo: should we assume we only want active variables or also extract ones that are commented out?
# Function to extract RANGE variables based on mode
def get_range(content, mode="active"):
    if pd.isna(content):
        return None  # Return None if content is missing

    # Extract active RANGE variables (not commented out)
    active_matches = re.findall(r"^\s*RANGE\s+([\w\s,]+)", content, re.MULTILINE)

    # Extract commented-out RANGE variables (lines starting with ": RANGE")
    commented_matches = re.findall(r"^\s*:\s*RANGE\s+([\w\s,]+)", content, re.MULTILINE)

    # Process active RANGE variables
    active_vars = [var.strip() for match in active_matches for var in re.split(r"[,\s]+", match) if var]

    # Process commented-out RANGE variables
    commented_vars = [var.strip() for match in commented_matches for var in re.split(r"[,\s]+", match) if var]

    if mode == "active":
        return active_vars if active_vars else None
    elif mode == "commented":
        return commented_vars if commented_vars else None
    elif mode == "all":
        return {"active": active_vars if active_vars else None, "commented": commented_vars if commented_vars else None}
    else:
        raise ValueError("Invalid mode! Choose from 'all', 'active', or 'commented'.")


# Function to extract only active RANGE variables, stopping at colons and the end of the line
def get_range(content):
    if pd.isna(content):
        return None  # Return None if content is missing

    # Extract all RANGE statements (each line separately), stopping before colons
    matches = re.findall(r"^\s*RANGE\s+([^\n:]*)", content, re.MULTILINE)

    if not matches:
        return None

    # Process active RANGE variables, ensuring they don't capture anything past the colon
    active_vars = [var.strip() for match in matches for var in re.split(r"[,\s]+", match) if var]

    return active_vars if active_vars else None  # Return only active variables
    
# Function to extract parameter names and values as a dictionary
def get_parameter(content):
    if pd.isna(content):  
        return None
    
    matches = re.findall(r"PARAMETER\s*\{([^}]*)\}", content, re.MULTILINE)

    if not matches:
        return None

    param_dict = {}
    
    for match in matches:
        for line in match.split("\n"):
            line = line.strip()
            if line.startswith(":"):  # Ignore commented-out lines
                continue
            param_match = re.match(r"(\w+)\s*=\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)", line)
            if param_match:
                param_name, param_value = param_match.groups()
                param_dict[param_name] = float(param_value)  

    return param_dict if param_dict else None  

# Function to extract only active STATE variables, ignoring comments (`:`) and unit values `(mV)`, etc.
def get_state(content):
    if pd.isna(content):  
        return None

    matches = re.findall(r"STATE\s*\{([^}]*)\}", content, re.MULTILINE)

    if not matches:
        return None

    state_vars = []
    for match in matches:
        for line in match.split("\n"):
            line = line.strip()
            if line.startswith(":"):  # Ignore fully commented-out lines
                continue
            line = re.split(r"\s*:\s*", line)[0]  # Remove inline comments (anything after `:`)
            clean_line = re.sub(r"\([^)]*\)", "", line).strip()  # Remove unit values
            if clean_line:
                state_vars.append(clean_line)

    return state_vars if state_vars else None  



# New function
def get_derivative(content):
    """
    If a DERIVATIVE block exists, return the number of derivative assignments (e.g., m' = ...).
    Otherwise, return the STATE variables (same behavior as get_state).
    """
    if pd.isna(content):
        return None

    text = str(content)

    # Grab all DERIVATIVE blocks (name is optional: e.g., "DERIVATIVE states { ... }")
    blocks = re.findall(r"DERIVATIVE\b[^\{]*\{([^}]*)\}", text, flags=re.IGNORECASE | re.DOTALL)

    if not blocks:
        # No derivative block → behave like get_state
        return get_state(content)

    def _strip_comments(s: str) -> str:
        cleaned = []
        for line in s.splitlines():
            line = line.strip()
            if line.startswith(":"):
                continue  # drop full-line comments
            # remove inline comments after first colon
            line = line.split(":", 1)[0].strip()
            if line:
                cleaned.append(line)
        return "\n".join(cleaned)

    # Count assignments of the form "<ident>' ="
    derivative_count = 0
    for blk in blocks:
        cleaned = _strip_comments(blk)
        assignments = re.findall(r"\b([A-Za-z_]\w*)'\s*=", cleaned)
        derivative_count += len(assignments)

    return derivative_count



# Function to extract only active GLOBAL variables, ignoring commented-out (`:`) ones
def get_global(content):
    if pd.isna(content):  
        return None

    matches = re.findall(r"^\s*GLOBAL\s+([^\n:]*)", content, re.MULTILINE)

    if not matches:
        return None

    global_vars = [var.strip() for match in matches for var in re.split(r"[,\s]+", match) if var]

    return global_vars if global_vars else None  


def get_net_receive(content):
    """
    Extracts all NET_RECEIVE block arguments from MOD file content.

    Args:
        content (str): The text content of the MOD file.

    Returns:
        list or None: A list of extracted NET_RECEIVE arguments, or None if not found.
    """
    if pd.isna(content):  # Handle missing content
        return None

    # Find all occurrences of NET_RECEIVE and extract arguments
    matches = re.findall(r"^\s*NET_RECEIVE\s*\(\s*([\w, ]+)\s*\)", content, re.MULTILINE)

    if not matches:
        return None

    net_receive_vars = [var.strip() for match in matches for var in re.split(r"[,\s]+", match) if var]

    return net_receive_vars if net_receive_vars else None



def get_point_process(content):
    """
    Extracts the POINT_PROCESS name from MOD file content.

    Args:
        content (str): The text content of the MOD file.

    Returns:
        str or None: The extracted POINT_PROCESS name, or None if not found.
    """
    if pd.isna(content):  # Handle missing content
        return None

    # Extract the POINT_PROCESS name, ignoring comments
    match = re.search(r"^\s*POINT_PROCESS\s+([^\n:]+)", content, re.MULTILINE)

    return match.group(1).strip() if match else None


    
# Function to extract webpage heading
def get_heading(url):
    try:
        response = requests.get(url, timeout=10)  # Fetch the webpage
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        
        # Try extracting heading from the most relevant tag
        heading = soup.find("h1")  # Look for <h1> (main title)
        return heading.text.strip() if heading else None  # Return text or None
    except requests.exceptions.RequestException:
        return None  # Return None if the request fail

# Function to extract citation (text inside parentheses)
def get_citation(heading):
    if pd.isna(heading):
        return None
    match = re.search(r"\(([^)]+)\)", heading)  # Find text inside parentheses
    return match.group(1) if match else None  # Extract citation


# Function to extract first author(s) (removes "et al." and "al" correctly)
def get_author(citation):
    if pd.isna(citation):
        return None

    # Extract first author(s) before "et al" or variants
    match = re.search(r"^([\w\s&\-,]+?)(?:\s+et\s+al\.?|et)?(?:,|\s|$)", citation)  
    first_author = match.group(1).strip() if match else None  

    # Remove any trailing "al" left behind
    if first_author:
        first_author = re.sub(r"\b(al)\b", "", first_author, flags=re.IGNORECASE).strip()

    return first_author

# Function to extract the first year from citation (including shortened years like '20)
def get_year(citation):
    if pd.isna(citation):
        return None
    match = re.search(r"\b(19|20)?\d{2}\b|'\d{2}", citation)  # Find 4-digit or short year ('20)
    if match:
        return match.group(0).replace("'", "")  # Remove apostrophe but keep year as '20' if short
    return None  # Return None if no year found






def has_electrode_or_clamp(mod_name, content):
    """
    Checks whether 'clamp' is present in the mod file name OR 
    'ELECTRODE_CURRENT' is present in the NEURON mod file content.

    Parameters:
    - mod_name (str): The name of the .mod file.
    - content (str): The content of the .mod file.

    Returns:
    - int: 1 if either 'clamp' is in the mod name OR 'ELECTRODE_CURRENT' is in the content, 0 otherwise.
    """
    if pd.isna(mod_name) and pd.isna(content):
        return None  # Return None if both are missing

    has_clamp = bool(re.search(r"clamp", str(mod_name), re.IGNORECASE)) if pd.notna(mod_name) else False
    has_electrode = bool(re.search(r"\bELECTRODE_CURRENT\b", str(content))) if pd.notna(content) else False

    return 1 if has_clamp or has_electrode else 0

def map_ion(value):
    value = value.lower()  # Normalize to lowercase

    # Define regex-based categorization rules
    patterns = [
        (r'ca.*i$', 'ca_i'),
        (r'ca.*o$', 'ca_o'),
        (r'cl.*i$', 'cl_i'),
        (r'cl.*o$', 'cl_o'),
        (r'k.*i$', 'k_i'),
        (r'k.*o$', 'k_o'),
        (r'na.*i$', 'na_i'),
        (r'na.*o$', 'na_o'),
        (r'hco3.*i$', 'other_i'),
        (r'hco3.*o$', 'other_o'),
        (r'mgi$', 'mg_i'),  
        (r'mgo$', 'mg_o'),  
        (r'^img$', 'i_mg'),  
        (r'^emg$', 'e_mg'),
        (r'^e.*ca', 'e_ca'),
        (r'^e.*k', 'e_k'),
        (r'^e.*na', 'e_na'),
        (r'^e.*mg', 'e_mg'),
        (r'^e.*', 'e_other'),
        (r'^i.*ca', 'i_cal'),
        (r'^i.*k', 'i_k'),
        (r'^i.*cl', 'i_cl'),
        (r'^i.*na$', 'i_na'),  # FIX: Ensure "ina" is classified as "i_na"
        (r'^i.*mg', 'i_mg'),
        (r'^i.*', 'i_other'),
        (r'.*i$', 'other_i'),  # General rule: Anything ending in "i" is "other_i"
        (r'.*o$', 'other_o')   # General rule: Anything ending in "o" is "other_o"
    ]
    # Apply the regex patterns
    for pattern, category in patterns:
        if re.search(pattern, value):
            return category

    return "unknown"  # Default category if no match is found

def count_states(df, column_name="state"):
    """Counts the number of states in each row of the specified column."""
    df["count_states"] = df[column_name].apply(lambda x: len(x) if isinstance(x, list) else 0)
    return df



def get_tau(param_dict):
    if not isinstance(param_dict, dict):
        return None, None  # Return separate None values for direct unpacking

    # Extract values where the key contains 'tau'
    tau_values = [v for k, v in param_dict.items() if 'tau' in k.lower()]
    
    # If no tau values found, return (None, None)
    if not tau_values:
        return None, None
    
    # Compute min and max
    return min(tau_values), max(tau_values)


def get_e(param_dict):
    if not isinstance(param_dict, dict):
        return [None, None]  # Handle cases where the value is not a dictionary

    #todo: modify the v pattern so it takes like 2 characters max
    # Regex pattern to match variations of reversal potential names
    pattern = re.compile(r"^(e|rev|v|shift).*", re.IGNORECASE)

    # Extract values where the key matches the pattern
    e_values = [v for k, v in param_dict.items() if pattern.match(k)]

    # If no values found, return [None, None]
    if not e_values:
        return [None, None]

    # Compute min and max reversal potential
    return min(e_values), max(e_values)



def has_mg(content):
    """
    Checks if 'mg' appears anywhere in the given content.

    Args:
        content (str): The text content to search.

    Returns:
        int: 1 if 'mg' is found, 0 otherwise.
    """
    if pd.isna(content):  # Handle missing content
        return 0

    return int(bool(re.search(r"mg", content, re.IGNORECASE)))  # Convert Boolean to int


def plot_countplot(
    df,
    col,
    subset_query=None,
    title=None,
    color='#4C72B0',
    horizontal=True,
    figsize=(8, 5),
    show_counts=False
):
    """
    Create a Seaborn countplot with options for filtering, orientation, and annotations.

    Parameters:
    -----------
    df : pandas.DataFrame
        Input data.
    col : str
        Column to count and plot.
    subset_query : str, optional
        Pandas query string to filter data before plotting (e.g., "type == 'Neither'").
    title : str, optional
        Title of the plot.
    color : str, optional
        Color of the bars.
    horizontal : bool, default True
        If True, plot horizontal bars; else vertical.
    figsize : tuple, default (8, 5)
        Figure size.
    show_counts : bool, default False
        If True, annotate bars with counts.
    """
    data = df.query(subset_query) if subset_query else df
    order = data[col].value_counts().index

    plt.figure(figsize=figsize)
    ax = sns.countplot(
        data=data,
        y=col if horizontal else None,
        x=None if horizontal else col,
        order=order,
        color=color
    )

    if show_counts:
        for p in ax.patches:
            count = int(p.get_width() if horizontal else p.get_height())
            if horizontal:
                ax.text(
                    p.get_width() + 0.5,
                    p.get_y() + p.get_height() / 2,
                    str(count),
                    va='center'
                )
            else:
                ax.text(
                    p.get_x() + p.get_width() / 2,
                    p.get_height() + 0.5,
                    str(count),
                    ha='center'
                )

    ax.set_title(title or f'Count of {col}')
    ax.set_xlabel('Count' if horizontal else col)
    ax.set_ylabel(col if horizontal else 'Count')
    ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))

    plt.tight_layout()
    plt.show()

# Highlight count < 10
def highlight_rare_rows(row):
    color = 'background-color: lightcoral' if row['count'] < 10 else ''
    return [color] * len(row)


def get_count_df(df, group_cols, sort_col=None):
    if sort_col is None:
        sort_col = group_cols[0]
    
    return (
        df
        .groupby(group_cols)
        .size()
        .reset_index(name='count')
        .assign(
            overall_pct = lambda d: (d['count'] / d['count'].sum() * 100).round(2),
            subtype_pct = lambda d: (
                d.groupby(group_cols[0])['count']
                .transform(lambda x: (x / x.sum()) * 100)
                .round(2)
            )
        )
        .sort_values([sort_col, 'count'], ascending=[True, False])
    )

def plot_partial_credit_heatmap(y_true, y_pred, similarity_matrix):
    """
    Plots a heatmap of average similarity scores between true and predicted labels.
    
    Parameters:
    - y_true: list or array of true labels (strings)
    - y_pred: list or array of predicted labels (strings)
    - similarity_matrix: pandas DataFrame with labels as index and columns, containing similarity scores
    """
    # Get all unique labels
    all_labels = sorted(set(y_true) | set(y_pred))
    
    # Build confusion-style count matrix
    confusion_counts = pd.DataFrame(0, index=all_labels, columns=all_labels)
    for true, pred in zip(y_true, y_pred):
        confusion_counts.loc[true, pred] += 1

    # Compute similarity-weighted scores
    weighted_scores = confusion_counts * similarity_matrix

    # Normalize to average similarity per true label
    normalized_similarity = weighted_scores.div(confusion_counts.sum(axis=1).replace(0, np.nan), axis=0)

    # Plot heatmap
    plt.figure(figsize=(12, 8))
    sns.heatmap(normalized_similarity, annot=True, cmap="YlGnBu", fmt=".2f")
    plt.title("Average Partial Credit Score: True vs Predicted")
    plt.xlabel("Predicted Label")
    plt.ylabel("True Label")
    plt.tight_layout()
    plt.show()

import re
import sys

def extract_membrane_potential_value(line: str):
    # Remove comments starting with colon
    line = line.split(':', 1)[0]
    # Remove all whitespace
    cleaned = re.sub(r'\s+', '', line)

    # Regex pattern
    pattern = r'^([a-zA-Z_][a-zA-Z0-9_]*)=([-+]?\d+(\.\d+)?([eE][-+]?\d+)?)[(]mV[)]$'
    match = re.match(pattern, cleaned)
    
    if match:
        return float(match.group(2))
    return None

def extract_comparison_values(expr: str):
    expr = re.sub(r':.*$', '', expr)  # Strip comments
    expr = re.sub(r'\s+', '', expr)   # Remove all whitespace

    var = 'v' if 'v' in expr else ('Vm' if 'Vm' in expr else None)
    if var is None:
        return None, None

    values = []

    # Pattern for `var` ... `[+/-] Number` (e.g., `v+30`, `v+vshift-40`)
    # This also covers cases where the *variable* has a leading sign within a larger expression
    # but the structure is essentially `( [+-]var ... [+-]Number )`.
    # We need to be careful with `sign_before_var` for this one.

    # Pattern for terms like `v+C` or `v-C` directly, or `Av+C` where A is 1 or -1 after preprocessing.
    # This should be the most direct way to get `C` for `v+/-C` or `(+-v)+C`.
    # Let's adjust this to specifically match `([+-]?var)` followed by `[+-]num`
    # and also `num[+-]([+-]?var)`.

    # Attempt to capture the coefficient of 'v' and the constant term, then solve.
    # This is still simplified for linear patterns.
    pattern_linear_term_extraction = re.compile(rf"""
        (?:
            # Case: Number +/- var (e.g., 57 - v, 30 + v)
            (?P<num_before>[-+]?\d+(?:\.\d+)?) \s* (?P<op_num_var>[+-]) \s* ({re.escape(var)})
            |
            # Case: var +/- Number (e.g., v + 30, -v + 19.88, vshift + v - 57)
            # This needs to handle a leading sign for the var.
            (?P<sign_var>[+-]?) ({re.escape(var)}) # Capture optional sign before var
            (?: \s* [+-] \s* [a-zA-Z_]\w* )* # Other vars/ops between var and number
            \s* (?P<op_var_num>[+-]) \s* (?P<num_after>[-+]?\d+(?:\.\d+)?)
        )
    """, re.VERBOSE)

    # Special handling for `-(v+shift+vsym+50)/7.4`
    pattern_nested_negation = re.compile(rf"""
        -\s*\( # Starts with - followed by (
        .*? # Non-greedy match for anything
        {re.escape(var)} # Contains the target variable
        (?: \s* [+-] \s* [a-zA-Z_]\w* )* # Optional other variables
        \s*
        (?P<op_final_nested>[+-]) # The operator before the constant
        \s*
        (?P<num_final_nested>\d+(?:\.\d+)?) # The positive constant
        \s*\) # Closing parenthesis
    """, re.VERBOSE)

    # --- Apply Patterns and Extract Values ---

    # For the linear term extraction pattern
    for match in pattern_linear_term_extraction.finditer(expr):
        if match.group('num_before'): # Matched: Number +/- var
            number = float(match.group('num_before'))
            op = match.group('op_num_var')
            # If `N - v`, means `N` is constant. `v=N`.
            # If `N + v`, means `N` is constant. `v=-N`.
            cmp_val = number if op == '-' else -number
            values.append(cmp_val)
        else: # Matched: [+-]var +/- Number
            number = float(match.group('num_after'))
            op = match.group('op_var_num')
            sign_var = match.group('sign_var') # Will be '-', '+' or ''

            # Effective coefficient of v (after preprocessing 1s)
            effective_var_coeff = -1.0 if sign_var == '-' else 1.0

            # Effective constant term (B) for Av+B
            # If op is '+', B is +number. If op is '-', B is -number.
            effective_constant = number if op == '+' else -number # Corrected logic

            # Solve Av + B = 0 => v = -B/A
            if effective_var_coeff != 0: # Should always be 1 or -1 here
                cmp_val = -effective_constant / effective_var_coeff
                values.append(cmp_val)


    for match in pattern_nested_negation.finditer(expr):
        number = float(match.group('num_final_nested'))
        op = match.group('op_final_nested')
        # This handles `-(v+50)` and `-(v-50)`
        # If op is '+', it's `-(v+N)`, which is `-v-N`. So `-v-N=0` => `v=-N`.
        # If op is '-', it's `-(v-N)`, which is `-v+N`. So `-v+N=0` => `v=N`.
        cmp_val = -number if op == '+' else number
        values.append(cmp_val)

    return list(set(values)) # Use set to remove duplicates


# Regex to find -1 times v or Vm (with optional decimals and spaces)
pattern_neg_one_mul = re.compile(r"-\s*1\.?0*\*\s*([vV]m?)")


def extract_v_comparisons(expr_str: str):
    # Replace with just - followed by the captured variable
    old_expr = expr_str
    expr_str = pattern_neg_one_mul.sub(r"-\g<1>", expr_str)
    if old_expr != expr_str:
        print(old_expr)
        print(expr_str)
    extracted_values = extract_comparison_values(expr_str)
    if None in extracted_values or not extracted_values:
        return None, None
    else:
        # Return min and max if values were found
        return min(extracted_values), max(extracted_values)


def extract_voltage_extrema(mod_content: str):
    values = []

    for line in mod_content.splitlines():
        # Strip comments
        code = line.split(':', 1)[0]

        # Skip empty lines
        if not code.strip():
            continue

        # Try membrane potential definition
        mv_val = extract_membrane_potential_value(code)
        if mv_val is not None:
            values.append(mv_val)

        # Try v comparison
        vmin, vmax = extract_v_comparisons(code)
        if vmin is not None:
            values.extend([vmin, vmax])

    if values:
        return min(values), max(values)
    return None, None

def check_map(df, mapped_col, original_col, fillna_value="_NA"):
    temp = df[[mapped_col, original_col]].copy()

    # Convert to string before fillna to ensure uniform types
    temp[mapped_col] = temp[mapped_col].astype("string").fillna(fillna_value)
    temp[original_col] = temp[original_col].astype("string").fillna(fillna_value)

    grouped = (
        temp.groupby([mapped_col, original_col])
        .size()
        .reset_index(name="n")
        .sort_values(by=mapped_col)
    )

    total_rows = len(temp)
    total_by_new = grouped.groupby(mapped_col)["n"].transform("sum")

    grouped["pct_new"] = (total_by_new / total_rows * 100).round(1).astype(str) + "%"
    grouped["pct_old"] = (grouped["n"] / total_rows * 100).round(1).astype(str) + "%"

    return grouped

def get_metrics_df(conf_input, labels=None):
    """
    Compute True Positives, Count, and TP % from a confusion matrix.

    Parameters:
        conf_input (DataFrame or ndarray): Confusion matrix
        labels (list or array-like, optional): Class labels (required if conf_input is ndarray)

    Returns:
        DataFrame with metrics per class
    """
    # Convert to DataFrame if needed
    if isinstance(conf_input, np.ndarray):
        if labels is None:
            raise ValueError("Must provide 'labels' if confusion matrix is a NumPy array.")
        conf_df = pd.DataFrame(conf_input, index=labels, columns=labels)
    else:
        conf_df = conf_input.copy()
        if labels is None:
            labels = conf_df.index.tolist()

    # Create metrics
    metrics_df = pd.DataFrame(index=labels)
    metrics_df["True Positives"] = np.diag(conf_df.values)
    metrics_df["Count"] = conf_df.sum(axis=1).values
    metrics_df["TP %"] = 100 * metrics_df["True Positives"] / metrics_df["Count"]
    metrics_df = metrics_df.round(2)

    return metrics_df


def count_code_lines(text: str) -> int:
    if not isinstance(text, str):
        return 0

    in_neuron_block_comment = False   # COMMENT ... ENDCOMMENT
    in_c_block_comment = False        # /* ... */ across lines
    count = 0

    for raw in text.splitlines():
        line = raw.strip()

        # Skip TITLE lines entirely
        if line.upper().startswith("TITLE "):
            continue

        # -------- NEURON COMMENT ... ENDCOMMENT --------
        if line.upper().startswith("COMMENT"):
            in_neuron_block_comment = True
            continue
        if line.upper().startswith("ENDCOMMENT"):
            in_neuron_block_comment = False
            continue
        if in_neuron_block_comment:
            continue

        # -------- C-style /* ... */ multi-line blocks --------
        if in_c_block_comment:
            # does this line close the block?
            if "*/" in line:
                in_c_block_comment = False
            continue

        # starts a C-style block?
        if line.startswith("/*") and "*/" not in line:
            in_c_block_comment = True
            continue

        # single-line C-style block comment
        if line.startswith("/*") and line.endswith("*/"):
            continue

        # -------- single-line comment prefixes --------
        # handles whitespace-prefixed comments like "   //FILE *" or "   : note"
        if line.startswith(("#", "//", ":", "::")):
            continue

        # -------- strip inline comments --------
        # remove any /* ... */ that occur inline on the same line
        line = re.sub(r"/\*.*?\*/", "", line)

        # then strip anything after // or # (simple but effective for .mod files)
        line = re.split(r"//|#", line, maxsplit=1)[0].rstrip()

        # after stripping, skip if empty
        if not line:
            continue

        count += 1

    return count

def has_s(content):
    if pd.isna(content):
        return 0
    # Regex looks for STATE { ... s ... } where 's' is a standalone token
    return int(bool(re.search(r'STATE\s*\{\s*[^}]*\bs\b[^}]*\}', content, re.IGNORECASE)))

def get_metrics_df(conf_input, labels=None):
    """
    Compute True Positives, Count, and TP % from a confusion matrix.

    Parameters:
        conf_input (DataFrame or ndarray): Confusion matrix
        labels (list or array-like, optional): Class labels (required if conf_input is ndarray)

    Returns:
        DataFrame with metrics per class
    """
    # Convert to DataFrame if needed
    if isinstance(conf_input, np.ndarray):
        if labels is None:
            raise ValueError("Must provide 'labels' if confusion matrix is a NumPy array.")
        conf_df = pd.DataFrame(conf_input, index=labels, columns=labels)
    else:
        conf_df = conf_input.copy()
        if labels is None:
            labels = conf_df.index.tolist()

    # Create metrics
    metrics_df = pd.DataFrame(index=labels)
    metrics_df["True Positives"] = np.diag(conf_df.values)
    metrics_df["Count"] = conf_df.sum(axis=1).values
    metrics_df["TP %"] = 100 * metrics_df["True Positives"] / metrics_df["Count"]
    metrics_df = metrics_df.round(2)

    return metrics_df

# === Config ===
SEED = 6
# ------------------------------------------------------------
# Helpers (tiny, procedural)
# ------------------------------------------------------------
def set_seed(seed=SEED):
    np.random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)

def clean_numeric_columns(df):
    """Clean column names and enforce numeric dtype for object columns."""
    df = df.copy()
    df.columns = df.columns.astype(str).str.replace(r"[\[\]<>]", "_", regex=True)
    for col in df.columns:
        if df[col].dtype == "object":
            df[col] = pd.to_numeric(df[col], errors="raise")
    return df

def encode_labels(train_s, test_s):
    """Fit a LabelEncoder on train_s and transform both train/test (as strings)."""
    le = LabelEncoder().fit(pd.Series(train_s).astype(str))
    y_tr = le.transform(pd.Series(train_s).astype(str))
    y_te = le.transform(pd.Series(test_s).astype(str))
    return le, y_tr, y_te

def plot_confusion(y_true, y_pred, labels, title, normalize=None, figsize=(10, 7)):
    cm = confusion_matrix(y_true, y_pred, labels=labels, normalize=normalize)
    fmt = ".2f" if normalize else "d"
    plt.figure(figsize=figsize)
    sns.heatmap(cm, annot=True, fmt=fmt, cmap="Blues",
                xticklabels=labels, yticklabels=labels, linewidths=0.5)
    plt.xlabel("Predicted"); plt.ylabel("True"); plt.title(title)
    plt.xticks(rotation=90); plt.yticks(rotation=0)
    plt.tight_layout(); plt.show()

def xgb_gain_importance(estimator, feature_names):
    """Return gain-based importances mapped to real feature names as a sorted Series."""
    booster = estimator.get_booster()
    score = booster.get_score(importance_type="gain")  # dict: {key -> gain}
    mapped = {}
    for k, v in score.items():
        if isinstance(k, str) and k.startswith('f') and k[1:].isdigit():
            idx = int(k[1:])
            name = feature_names[idx] if idx < len(feature_names) else k
        else:
            name = k
        mapped[name] = float(v)
    s = pd.Series(mapped, dtype=float)
    s = s.reindex(feature_names).fillna(0.0).sort_values(ascending=False)
    return s

def plot_top_features(imp_series, title, topn=15, figsize=(9, 6)):
    top = imp_series.head(topn)[::-1]
    plt.figure(figsize=figsize)
    top.plot.barh()
    plt.title(title); plt.xlabel("Gain importance"); plt.ylabel("Feature")
    plt.tight_layout(); plt.show()
