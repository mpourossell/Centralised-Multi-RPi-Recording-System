import os
import shutil
import random

def copy_random_images(source_dir, destination_dir, num_images):
    # Get a list of all image files in the source directory
    image_files = [f for f in os.listdir(source_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff'))]

    # Check if the number of requested images is greater than the available images
    if num_images > len(image_files):
        print(f"Warning: Requested {num_images} images, but only {len(image_files)} images available.")

    # Select random images
    selected_images = random.sample(image_files, min(num_images, len(image_files)))
    if not os.path.exists(destination_dir):
        os.mkdir(destination_dir)

    existing_path_dir = r'C:\Users\mpou\OneDrive - CREAF\Documentos\2nd Chapter_Computer vision\03_image_data\annotated\Pose estimation\500_sample'
    # Copy selected images to the destination directory
    for image in selected_images:
        source_path = os.path.join(source_dir, image)
        destination_path = os.path.join(destination_dir, image)
        existing_path = os.path.join(existing_path_dir, image)
        if not os.path.exists(existing_path) and not os.path.exists(destination_path):
            shutil.copy2(source_path, destination_path)
            print(f"Image copied: {destination_path}")
        else:
            print(f"Image already exists: {destination_path}.")

if __name__ == '__main__':
    source_directory = r'C:\Users\mpou\Documents\Random_frames_selection'
    destination_directory = r"C:\Users\mpou\OneDrive - CREAF\Documentos\2nd Chapter_Computer vision\03_image_data\annotated\Pose estimation\2000_sample"
    num_images_to_copy = 200

    copy_random_images(source_directory, destination_directory, num_images_to_copy)