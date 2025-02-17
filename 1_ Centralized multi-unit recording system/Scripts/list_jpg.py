# This script creates a list of all filenames of the recorded images in each sequence. This is useful to keep
# the timestamps of each frame, as when later converted to a video filenames of each frames are lost.

import os

directory_path = "/home/pi/pirecorder/recordings"
output_path = "/home/pi/pirecorder/lists"

# Ensure the output directory exists
os.makedirs(output_path, exist_ok=True)

# Iterate over directories in the specified path
for root, dirs, files in os.walk(directory_path):
    for directory in dirs:
        current_dir = os.path.join(root, directory)
        file_list = sorted(os.listdir(current_dir))
        txt_path = os.path.join(output_path, f'{directory}.txt')
        
        # Check if the text file already exists
        if os.path.exists(txt_path):
            with open(txt_path, 'r') as existing_file:
                existing_lines = existing_file.readlines()
            
            # Check if the number of files in the directory is equal to the number of lines in the existing file
            if len(existing_lines) is not len(file_list):
                with open(txt_path, 'w') as existing_file:
                    for filename in file_list:
                        existing_file.write(f'{filename}\n')
                    
        else:
            # Create a new txt file with the list of filenames
            with open(txt_path, 'w') as txtfile:
                for filename in file_list:
                    txtfile.write(f'{filename}\n')
