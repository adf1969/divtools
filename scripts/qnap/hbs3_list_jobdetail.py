#!/usr/bin/env python3
"""
hbs3_list_jobdetail.py

This script extracts job details from the HBS3 configuration database and outputs them in CSV format.
# v01: 2024-11-28: Initial version to extract and display HBS3 job details.
# v02: 2024-11-28: Added functionality to output CSV to screen or file based on -o argument.
# v03: 2024-11-28: Added logging to track errors and enhance debugging.
# v04: 2024-11-28: Fixed handling of list objects in job data.
# v05: 2024-11-28: Updated to output one row per sync pair, repeating common values.
# v06: 2024-11-28: Added detailed debugging for empty or unexpected sync.pairs data.
# v07: 2024-11-28: Fixed handling of sync.pairs with added verification and logging.
# v08: 2024-11-28: Added a -q flag to suppress warnings for jobs without sync.pairs.
"""

import argparse
import csv
import json
import logging
import os
import sqlite3
import sys


def setup_logging():
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )


def fetch_job_data(db_path):
    """Connect to the HBS3 database and fetch job data."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM jobs")
        rows = cursor.fetchall()
        conn.close()
        return [json.loads(row[0]) for row in rows]
    except Exception as e:
        logging.error(f"Failed to fetch job data: {e}")
        sys.exit(1)


def process_job(job, suppress_warnings=False):
    """Process a single job and extract sync.pairs data."""
    job_name = job.get('name', 'Unknown')
    logging.debug(f"Processing job: {job_name}")
    
    # Look for 'sync.pairs' directly in the job dictionary
    sync_pairs = job.get('sync.pairs', [])
    
    if not sync_pairs or not isinstance(sync_pairs, list):
        if not suppress_warnings:
            logging.warning(f"No valid 'sync.pairs' found for job: {job_name}. Full job data: {job}")
        return []

    processed_pairs = []
    for pair in sync_pairs:
        local_root = pair.get('local.root')
        remote_root = pair.get('remote.root')
        if not local_root or not remote_root:
            logging.warning(f"Invalid pair in job: {job_name}. Pair data: {pair}")
            continue
        
        # Extract relevant details for output
        processed_pairs.append({
            'Job Name': job_name,
            'Sync Direction': job.get('sync.direction', 'Unknown'),  # Access sync.direction directly
            'Local Folder': local_root,
            'Remote Folder': remote_root,
            'Frequency': job.get('schedule', [{'type': 'unknown'}])[0].get('type', 'unknown'),
        })
    
    return processed_pairs


def process_jobs(jobs, suppress_warnings=False):
    """Process all jobs and compile output data."""
    all_processed = []
    for job in jobs:
        processed = process_job(job, suppress_warnings)
        if processed:
            all_processed.extend(processed)
    return all_processed


def output_to_csv(data, output_file=None):
    """Output processed data to CSV."""
    if not data:
        logging.warning("No valid jobs found with sync.pairs.")
        print("Job Name,Sync Direction,Local Folder,Remote Folder,Frequency")
        return

    headers = ['Job Name', 'Sync Direction', 'Local Folder', 'Remote Folder', 'Frequency']
    if output_file:
        try:
            with open(output_file, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=headers)
                writer.writeheader()
                writer.writerows(data)
            logging.info(f"Job details have been written to {output_file}.")
        except Exception as e:
            logging.error(f"Failed to write to file {output_file}: {e}")
    else:
        print(",".join(headers))
        for row in data:
            print(",".join([str(row[h]) for h in headers]))
        logging.info("Job details have been output to the screen.")


def main():
    parser = argparse.ArgumentParser(description="Extract HBS3 job details and output them in CSV format.")
    parser.add_argument(
        "-d", "--db", 
        default="/mnt/HDA_ROOT/.config/cloudconnector/CloudConnector3/config.db", 
        help="Path to the HBS3 configuration database."
    )
    parser.add_argument(
        "-o", "--output", 
        help="Output file for CSV data. If not specified, outputs to the console."
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Suppress warnings for jobs without sync.pairs."
    )
    args = parser.parse_args()

    setup_logging()

    db_path = args.db
    if not os.path.exists(db_path):
        logging.error(f"Database file not found at {db_path}")
        sys.exit(1)

    logging.info(f"Connecting to database at: {db_path}")
    jobs = fetch_job_data(db_path)
    logging.info(f"Fetched {len(jobs)} job entries from the database.")

    processed_data = process_jobs(jobs, suppress_warnings=args.quiet)
    output_to_csv(processed_data, args.output)


if __name__ == "__main__":
    main()
