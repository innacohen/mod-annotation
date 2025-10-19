from _utils import *

# Set up logging
LOGS_DIR = os.path.join(os.getcwd(), "../logs")
os.makedirs(LOGS_DIR, exist_ok=True)

LOG_FILE_FP = os.path.join(LOGS_DIR, f"inc_download_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Define directory for saving .inc files
METADATA_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
INCLUDES_DIR = os.path.join(RAW_DATA_DIR, "nmodl/includes")
os.makedirs(INCLUDES_DIR, exist_ok=True)

# Load metadata
print(f"Loading metadata from {METADATA_FP}")
raw_json_df = pd.read_json(METADATA_FP)
print(f"Loaded metadata with {len(raw_json_df)} entries")

# Filter for files with includes
files_with_includes = raw_json_df.query("has_include == True").copy()
print(f"Found {len(files_with_includes)} MOD files with INCLUDE statements")

# Function to get parent directory URL from a file URL
def get_parent_dir_url(url):
    parsed = urlparse(url)
    path_parts = parsed.path.rstrip('/').split('/')
    # Remove the file part and join back
    parent_path = '/'.join(path_parts[:-1]) + '/'
    parent_url = parsed.scheme + "://" + parsed.netloc + parent_path
    return parent_url

# Function to extract .inc file links from a directory page
def get_inc_files_from_dir(dir_url):
    inc_files = []
    try:
        response = requests.get(dir_url)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Look for links (different sites have different structures)
        for link in soup.find_all('a'):
            href = link.get('href')
            if href and href.lower().endswith('.inc'):
                # Convert relative URL to absolute
                full_url = urljoin(dir_url, href)
                inc_files.append((os.path.basename(href), full_url))
                
    except Exception as e:
        logging.error(f"Error fetching directory {dir_url}: {e}")
        print(f"Error fetching directory {dir_url}: {e}")
    
    return inc_files

# Function to download a file
def download_file(url, output_path):
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        with open(output_path, "wb") as f:
            f.write(response.content)
        return True
    except Exception as e:
        logging.error(f"Error downloading {url}: {e}")
        print(f"Error downloading {url}: {e}")
        return False

# Process each file with includes
successful_dirs = 0
successful_downloads = 0
failed_downloads = 0
all_inc_files = []

print(f"Scanning parent directories for .inc files...")
for idx, row in tqdm(files_with_includes.iterrows(), total=len(files_with_includes)):
    # Get parent directory URL
    mod_url = row['url']
    parent_dir = get_parent_dir_url(mod_url)
    logging.info(f"Checking parent directory: {parent_dir}")
    
    # Find .inc files in the directory
    inc_files = get_inc_files_from_dir(parent_dir)
    
    if inc_files:
        successful_dirs += 1
        logging.info(f"Found {len(inc_files)} .inc files in {parent_dir}")
        
        # Add to our master list, with parent directory info
        for inc_filename, inc_url in inc_files:
            all_inc_files.append({
                'parent_dir': parent_dir,
                'inc_filename': inc_filename,
                'inc_url': inc_url,
                'mod_file_hash': row['file_hash'] if 'file_hash' in row else None
            })

# Remove duplicates based on URL
unique_inc_files = pd.DataFrame(all_inc_files).drop_duplicates(subset=['inc_url'])
print(f"Found {len(unique_inc_files)} unique .inc files across {successful_dirs} directories")

# Download all unique .inc files
print(f"Downloading .inc files to {INCLUDES_DIR}")
for idx, row in tqdm(unique_inc_files.iterrows(), total=len(unique_inc_files)):
    inc_url = row['inc_url']
    inc_filename = row['inc_filename']
    output_path = os.path.join(INCLUDES_DIR, inc_filename)
    
    # Check if we've already downloaded this file
    if os.path.exists(output_path):
        logging.info(f"Skipping {inc_filename} - already exists")
        successful_downloads += 1
        continue
    
    # Download the file
    success = download_file(inc_url, output_path)
    if success:
        successful_downloads += 1
    else:
        failed_downloads += 1

# Log results
stats_message = f"""
.inc File Download Summary:
- Scanned {len(files_with_includes)} MOD files with INCLUDE statements
- Found {successful_dirs} directories containing .inc files
- Found {len(all_inc_files)} total .inc files (with duplicates)
- Found {len(unique_inc_files)} unique .inc files
- Successfully downloaded: {successful_downloads}
- Failed downloads: {failed_downloads}
"""

print(stats_message)
logging.info(stats_message)

# Create a CSV file mapping MOD files to their included .inc files
mapping_df = pd.DataFrame(all_inc_files)
mapping_path = os.path.join(RAW_DATA_DIR, "mod_inc_mapping.csv")
mapping_df.to_csv(mapping_path, index=False)
print(f"Saved mapping between MOD files and .inc files to {mapping_path}")

# Display summary of downloaded .inc files
if len(os.listdir(INCLUDES_DIR)) > 0:
    print(f"\nDownloaded .inc files:")
    for filename in sorted(os.listdir(INCLUDES_DIR)):
        file_path = os.path.join(INCLUDES_DIR, filename)
        file_size = os.path.getsize(file_path) / 1024  # Size in KB
        print(f"- {filename} ({file_size:.1f} KB)")
# %%
