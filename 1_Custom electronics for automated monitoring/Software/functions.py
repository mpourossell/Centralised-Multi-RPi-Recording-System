# Some functions that may be used in other scripts

import os
from datetime import datetime, timedelta

def count_files_in_folders(directory):
    # Get the current date
    current_date = datetime.now()

    # Calculate the date for the previous day
    previous_day = current_date - timedelta(days=1)

    # Format the date in the YYYY-MM-DD format
    formatted_date = previous_day.strftime("%Y-%m-%d")

    # Create a list to store the counts
    counts = []

    # Iterate over subdirectories in the given directory
    for subdir in os.listdir(directory):
        subdir_path = os.path.join(directory, subdir)

        # Check if it's a directory and created on the previous day
        if os.path.isdir(subdir_path):
            creation_time = datetime.fromtimestamp(os.path.getctime(subdir_path))
            if creation_time.date() == previous_day.date():
                # Count the number of files in the directory
                file_count = len([f for f in os.listdir(subdir_path) if os.path.isfile(os.path.join(subdir_path, f))])
                counts.append((subdir, file_count))

    return counts

# Check system performance

# Replace '/path/to/your/directory' with the actual path to your directory
directory_path = '/home/pi/pirecorder/recordings'

# Get the counts for files in folders created on the previous day
result = count_files_in_folders(directory_path)

# Print the results
total_count = 0
for subdir, file_count in sorted(result):
    total_count += file_count
    print(f"'{subdir}' cointains {file_count} files.")
print(f'TOTAL_COUNT = {total_count}')

