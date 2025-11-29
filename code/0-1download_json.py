from _utils import *


# === CONFIG ===
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
LOG_FP = os.path.join(LOGS_DIR, f"0-1download_log_{TIMESTAMP}.txt")

os.makedirs(RAW_DATA_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

# === READ ANNOTATIONS ===
df = pd.read_excel(ANNOTATIONS_FP)
ANNOTATED_SAMPLES = df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(ANNOTATED_SAMPLES)} annotated samples")

annotated_df = df[df["file_hash"].isin(ANNOTATED_SAMPLES)].copy()

failed_download_count = 0
failed_file_hashes = []
downloaded_data = []

print(f"Starting download of {len(annotated_df)} annotated ModelDB entries")

# === HELPER FUNCTIONS ===

def get_direct_download_url(url):
    match = re.search(r"https://modeldb\.science/(\d+)\?tab=2&file=(.+)", url)
    if match:
        model_id, file_path = match.groups()
        return f"https://modeldb.science/getModelFile?model={model_id}&file={file_path}", file_path
    return None, None

def get_includes(content):
    """Extract INCLUDE statements (excluding comments)."""
    if content is None:
        return []
    comment_pattern = re.compile(r'COMMENT.*?ENDCOMMENT', re.DOTALL)
    content_no_comments = comment_pattern.sub('', content)
    content_no_comments = re.sub(r':.*$', '', content_no_comments, flags=re.MULTILINE)
    include_pattern = re.compile(r'^\s*INCLUDE\s+(.+?)(?:\s|$)', re.MULTILINE | re.IGNORECASE)
    matches = include_pattern.findall(content_no_comments)
    cleaned_matches = [m.strip('"\'') for m in matches]
    return cleaned_matches if cleaned_matches else []

def extract_model_id(url):
    """Extract the model_id from a ModelDB URL."""
    if 'getModelFile' in url:
        match = re.search(r'model=(\d+)', url)
        if match:
            return match.group(1)
    match = re.search(r'modeldb\.science/(\d+)', url)
    if match:
        return match.group(1)
    return None

def get_model_creation_date(model_id):
    """Fetch model creation date via ModelDB API."""
    if not model_id:
        return None
    api_url = f"https://modeldb.science/api/v1/models/{model_id}?indent=4"
    try:
        response = requests.get(api_url, timeout=10)
        response.raise_for_status()
        model_data = response.json()
        return model_data.get("created")
    except Exception:
        return None

def get_inc_download_links(url):
    """
    Given a ModelDB file URL, go one directory up and return list of .inc direct download URLs.
    Example:
    https://modeldb.science/9889?tab=2&file=lytton97/nc_syn.mod
        → parent dir: .../lytton97
        → returns direct links like:
          https://modeldb.science/getModelFile?model=9889&file=lytton97/presyn.inc
    """
    try:
        model_id = extract_model_id(url)
        if not model_id:
            return []

        # Determine parent directory path inside the model
        match = re.search(r"file=([^&]+)", url)
        if not match:
            return []
        file_path = match.group(1)
        parent_dir = "/".join(file_path.split("/")[:-1])  # e.g., lytton97
        base_url = f"https://modeldb.science/{model_id}?tab=2&file={parent_dir}" if parent_dir else f"https://modeldb.science/{model_id}?tab=2"

        # Fetch HTML directory listing
        response = requests.get(base_url, timeout=10)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")
        links = soup.find_all("a", href=True)
        inc_urls = []

        for link in links:
            href = link["href"]
            if href.endswith(".inc"):
                filename = href.split("/")[-1]
                full_path = f"{parent_dir}/{filename}" if parent_dir else filename
                inc_urls.append(f"https://modeldb.science/getModelFile?model={model_id}&file={full_path}")

        return inc_urls if inc_urls else []
    except Exception:
        return []


def get_h_download_links(url):
    """
    Given a ModelDB file URL, go one directory up and return list of .h direct download URLs.
    Example:
    https://modeldb.science/106891?tab=2&file=b07dec27_20091025/misc.mod
        → parent dir: .../b07dec27_20091025
        → returns direct links like:
          https://modeldb.science/getModelFile?model=106891&file=b07dec27_20091025/misc.h
    """
    try:
        model_id = extract_model_id(url)
        if not model_id:
            return []

        # Determine parent directory path inside the model
        match = re.search(r"file=([^&]+)", url)
        if not match:
            return []
        file_path = match.group(1)
        parent_dir = "/".join(file_path.split("/")[:-1])  # e.g., ncdemo
        base_url = f"https://modeldb.science/{model_id}?tab=2&file={parent_dir}" if parent_dir else f"https://modeldb.science/{model_id}?tab=2"

        # Fetch HTML directory listing
        response = requests.get(base_url, timeout=10)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")
        links = soup.find_all("a", href=True)
        h_urls = []

        for link in links:
            href = link["href"]
            if href.endswith(".h"):
                filename = href.split("/")[-1]
                full_path = f"{parent_dir}/{filename}" if parent_dir else filename
                h_urls.append(f"https://modeldb.science/getModelFile?model={model_id}&file={full_path}")

        return h_urls if h_urls else []
    except Exception:
        return []


# === MAIN LOOP ===
with open(LOG_FP, "w", encoding="utf-8") as log_file:
    log_file.write(f"=== ModelDB Download Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Found {len(ANNOTATED_SAMPLES)} annotated samples\n")
    log_file.write(f"Starting download of {len(annotated_df)} annotated ModelDB entries\n\n")
    log_file.write("=== DOWNLOAD DETAILS ===\n")

    for _, row in tqdm(annotated_df.iterrows(), total=len(annotated_df), desc="Downloading ModelDB files"):
        row_id = row["row_id"]
        file_hash = row["file_hash"]
        url = row["url"]

        model_id = extract_model_id(url)
        created_date = get_model_creation_date(model_id) if model_id else None
        direct_url, file_path = get_direct_download_url(url)

        entry_data = {
            "row_id": row_id,
            "file_hash": file_hash,
            "raw_sha": row["raw_sha"],
            "count": row["count"],
            "url": url,
            "model_id": model_id,
            "created_date": created_date,
            "download_url": direct_url,
            "filename": file_path,
            "content": None,
            "error_code": None,
            "has_include": 0,
            "download_inc_url": [],
            "has_h_url": 0,  # NEW: flag for presence of .h files
            "download_h_url": [],  # NEW: list of .h download URLs
            "download_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        if not direct_url:
            error_msg = f"FAILED: {file_hash} - Skipping invalid URL: {url}"
            print(error_msg)
            log_file.write(f"{error_msg}\n")
            entry_data["error_code"] = "Invalid URL"
            failed_download_count += 1
            failed_file_hashes.append(file_hash)
        else:
            try:
                response = requests.get(direct_url, timeout=10)
                response.raise_for_status()
                entry_data["content"] = response.text

                include_files = get_includes(response.text)
                entry_data["has_include"] = 1 if include_files else 0

                # Collect .inc download links if include statements present
                if include_files:
                    entry_data["download_inc_url"] = get_inc_download_links(url)

                # NEW: Always check for .h files in the same directory
                h_file_urls = get_h_download_links(url)
                entry_data["has_h_url"] = 1 if h_file_urls else 0
                entry_data["download_h_url"] = h_file_urls

                log_file.write(f"SUCCESS: {file_hash} - Successfully downloaded\n")
                
                # Optional: log if .h files were found
                if h_file_urls:
                    log_file.write(f"  Found {len(h_file_urls)} .h file(s): {', '.join([u.split('/')[-1] for u in h_file_urls])}\n")

            except requests.exceptions.HTTPError as http_err:
                error_msg = f"FAILED: {file_hash} - HTTP Error {response.status_code}: {http_err}"
                print(error_msg)
                log_file.write(f"{error_msg}\n")
                entry_data["error_code"] = str(response.status_code)
                failed_download_count += 1
                failed_file_hashes.append(file_hash)

            except requests.exceptions.RequestException as e:
                error_msg = f"FAILED: {file_hash} - Request Error: {str(e)}"
                print(error_msg)
                log_file.write(f"{error_msg}\n")
                entry_data["error_code"] = "Request Error"
                failed_download_count += 1
                failed_file_hashes.append(file_hash)

        downloaded_data.append(entry_data)

    # === SAVE RESULTS ===
    with open(JSON_FP, "w", encoding="utf-8") as json_file:
        json.dump(downloaded_data, json_file, indent=4)

    total_entries = len(downloaded_data)
    successful_downloads = total_entries - failed_download_count

    summary = f"\n=== DOWNLOAD SUMMARY ===\n"
    summary += f"Total entries: {total_entries}\n"
    summary += f"Successful downloads: {successful_downloads}\n"
    summary += f"Failed downloads: {failed_download_count}\n"

    print(summary)
    log_file.write(summary)

    if failed_download_count > 0:
        log_file.write(f"\n=== FAILED FILE HASHES ({failed_download_count}) ===\n")
        for fh in failed_file_hashes:
            log_file.write(f"{fh}\n")

print(f"Complete log written to: {LOG_FP}")