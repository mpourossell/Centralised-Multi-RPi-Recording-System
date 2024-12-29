import cv2
import os
import random

def extract_random_frames(input_video, out_dir, n):
    video_name = os.path.splitext(os.path.split(input_video)[1])[0]
    vidcap = cv2.VideoCapture(input_video)

    # Check if the video file is opened successfully
    if not vidcap.isOpened():
        print(f"Error opening video file: {input_video}")
        return

    # Get total number of frames
    total_frames = int(vidcap.get(cv2.CAP_PROP_FRAME_COUNT))

    if total_frames == 0:
        print(f"No frames in video: {input_video}")
        return

    for i in range(n):
        random_frame_number = random.randint(0, total_frames - 1)

        # Set frame position
        vidcap.set(cv2.CAP_PROP_POS_FRAMES, random_frame_number)
        success, image = vidcap.read()

        if success:
            print('Working on ' + video_name)
            if not os.path.exists(out_dir):
                os.mkdir(out_dir)
            filename = os.path.join(out_dir, f'{video_name}_frame{random_frame_number}.jpg')
            cv2.imwrite(filename, image)
            print(f'Image randomly extracted and saved: {video_name}_frame{random_frame_number}.jpg')
        else:
            print(f"Failed to read frame {random_frame_number} from video: {input_video}")

    vidcap.release()

if __name__ == '__main__':
    in_dir = "your_directory_with_videos_path"
    out_dir = "random_frames_directory_path"
    n = 50 # Select 50 frames from each video

    for file in os.listdir(in_dir)[207:]:

        if file.endswith('.mp4') or file.endswith('.avi'): # Adjust the extension based on your video files
            print(f'File size is = {os.stat(os.path.join(in_dir, file)).st_size/(1024 * 1024)}')
            if (os.stat(os.path.join(in_dir, file)).st_size/(1024 * 1024)) > 2: # Select videos bigger than 2MB
                video_path = os.path.join(in_dir, file)
                print(video_path)
                extract_random_frames(video_path, out_dir, n)
            else:
                print(f'Video {file} size is < 2MB')
