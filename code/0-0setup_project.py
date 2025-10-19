from pathlib import Path

# Project root (one level up from script)
PROJECT_DIR = Path(__file__).parent.parent

# Create project directories
dirs = [
    "data/raw",
    "data/clean", 
    "annotations",
    "logs",
    "output",
    "figures"
]

# Create directories
for d in dirs:
    (PROJECT_DIR / d).mkdir(parents=True, exist_ok=True)
    
# Create path helper file
with open(PROJECT_DIR / "code" / "path_utils.py", "w") as f:
    f.write("""
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.parent
DATA_DIR = PROJECT_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
CLEAN_DATA_DIR = DATA_DIR / "clean"
ANNOTATIONS_DIR = PROJECT_DIR / "annotations"
LOGS_DIR = PROJECT_DIR / "logs"
OUTPUT_DIR = PROJECT_DIR / "output"
FIGURES_DIR = PROJECT_DIR / "figures"

def get_path(*segments):
    return PROJECT_DIR.joinpath(*segments)
""")

print(f"Project structure created at: {PROJECT_DIR}")
print("Import paths with: from path_utils import PROJECT_DIR, RAW_DATA_DIR, ANNOTATIONS_DIR")