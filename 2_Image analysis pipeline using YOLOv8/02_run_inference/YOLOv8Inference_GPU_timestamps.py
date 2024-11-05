import cv2
import os
from ultralytics import YOLO  # Make sure you have the YOLO class defined in the specified module
import torch
from PIL import Image, ImageDraw
import glob
import numpy as np
import pytesseract
from datetime import datetime, timedelta
import fnmatch
import ffmpeg
import shutil
import concurrent.futures
# from helpers import imgtovid

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe" # for Windows PC

# Read timestamp function
def read_timestamp(frame, ROIxywh, th):
    #pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
    ROI = frame[ROIxywh[1]:ROIxywh[1] + ROIxywh[3], ROIxywh[0]:ROIxywh[0] + ROIxywh[2]]

    # Pre-process image for text detection
    im = cv2.resize(ROI, None, fx=10, fy=10, interpolation=cv2.INTER_CUBIC)
    img_gray = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY)
    ret, thresh = cv2.threshold(img_gray, th, 255, cv2.THRESH_BINARY)
    #cv2.imshow('ROIxywh', thresh)
    #cv2.waitKey(5000)
    #cv2.destroyAllWindows()

    # Text detection
    text = pytesseract.image_to_string(thresh, lang='eng')
    new_text = text.replace(" ", "")
    new_text = ''.join((new_text.split('\n')))
    return new_text[-6:]

# Save images with keypoints data
def save_images(f_num, result, video_name, out_dir):
    # Save images
    keypoints_show = result.keypoints.xy.int().cpu().numpy()
    img_array = result.plot(kpt_line=True, kpt_radius=6)  # plot a BGR array of predictions
    im = Image.fromarray(img_array[..., ::-1])  # Convert array to a PIL Image

    try:
        draw = ImageDraw.Draw(im)
        # Filter out (0, 0) coordinates
        filtered_keypoints = [(x, y) for x, y in keypoints_show[0] if (x, y) != (0, 0)]

        # Draw lines between consecutive keypoints
        for i in range(len(filtered_keypoints) - 1):
            draw.line([filtered_keypoints[i], filtered_keypoints[i + 1]], fill=(0, 0, 255), width=1)

        filtered_keypoints2 = [(x, y) for x, y in keypoints_show[1] if (x, y) != (0, 0)]

        # Draw lines between consecutive keypoints2
        for i in range(len(filtered_keypoints2) - 1):
            draw.line([filtered_keypoints2[i], filtered_keypoints2[i + 1]], fill=(0, 0, 255), width=1)
        if not os.path.exists(os.path.join(out_dir, f'frames')):
            os.mkdir(os.path.join(out_dir, f'frames'))
        if not os.path.exists(os.path.join(out_dir, f'frames', video_name)):
            os.mkdir(os.path.join(out_dir, f'frames', video_name))

        im.save(os.path.join(out_dir, f'frames', video_name, f'{video_name}_{f_num:05d}.jpg'))
    except:
        if not os.path.exists(os.path.join(out_dir, f'frames')):
            os.mkdir(os.path.join(out_dir, f'frames'))
        if not os.path.exists(os.path.join(out_dir, f'frames', video_name)):
            os.mkdir(os.path.join(out_dir, f'frames', video_name))
        im.save(os.path.join(out_dir, f'frames', video_name, f'{video_name}_{f_num:05d}.jpg'))


def jpgtovid(in_dir, out_dir, fps):
    video_name = os.path.split(in_dir)[1]
    video_path = os.path.join(out_dir, f'{video_name}_processed.mp4')
    if not os.path.exists(video_path):
        print(f'Starting conversion of: {in_dir}')
        img_array = []
        for filename in glob.glob(os.path.join(in_dir, '*.jpg')):
            print(f'Working on file: {filename}')
            img = cv2.imread(filename)
            height, width, layers = img.shape
            size = (width, height)
            img_array.append(img)
        video = cv2.VideoWriter(video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (640, 480))
        for i in range(len(img_array)):
            video.write(img_array[i])
        video.release()
        print('Video "' + video_name + '.mp4" created successfully :D')
    else: print('Skipping conversion of "' + video_name + '.mp4" already exists. ')

def ffmpeg_imgtovid(in_dir, out_dir):
    video_name = os.path.split(in_dir)[1]
    video_path = os.path.join(out_dir, f'{video_name}.mp4')

    if os.path.exists(video_path) == False:
        if os.path.exists(in_dir) == False:
            os.mkdir(in_dir)
        if len(fnmatch.filter(os.listdir(in_dir), "*.*")) < 300:  # if recording is less than 500 frames
            try:
                video = (ffmpeg
                         .input(os.path.abspath(in_dir + '/*.jpg'), pattern_type='glob', framerate=1)
                         .output(video_path, vcodec='libx264', pix_fmt='yuv420p')
                         .run()
                         )
            except:
                pass
        else:
            try:
                video = (ffmpeg
                         .input(os.path.abspath(in_dir + '/*.jpg'), pattern_type='glob', framerate=120)
                         .output(video_path, vcodec='libx264', pix_fmt='yuv420p')
                         .run()
                         )
            except:
                pass
    else:
        try:
            cap = cv2.VideoCapture(video_path)
            vidframes = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            # Count number of frames of recording directory
            dirframes = len(fnmatch.filter(os.listdir(in_dir), "*.*"))
            # print("Frames in Video " + sub_dir + "  = " + str(vidframes))
            # print("Frames in folder " + sub_dir + "  = " + str(dirframes))
            if vidframes < (dirframes - 60):
                video = (ffmpeg
                         .input(os.path.abspath(in_dir + '/*.jpg'), pattern_type='glob', framerate=120)
                         .output(video_path, vcodec='libx264', pix_fmt='yuv420p')
                         .run(overwrite_output=True)
                         )
            else:
                pass  # print('file ' + outvid + ' already exists. Skipping conversion.')

        except:
            print(f'file {video_path} already exists. Skipping conversion.')



# Main function to run YOLOv8 inference on a video
def run_yolo_inference(weights_path, video_path, out_dir, save_csv = True, save_video = False, batch_size = None):
    print(f'Starting to run YOLO funciton...')
    torch.cuda.set_device(0)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Load YOLO model
    model = YOLO(weights_path)
    model.to(device=device)
    print('Working under device: ', model.device.type)

    # Extract video name
    video_name_ext = os.path.split(video_path)[1]
    video_name = video_name_ext[:-4]
    print(f'Video_path = {video_path}')

    if save_csv == True:
        csv_dir = os.path.join(out_dir, 'processed_csv')
        if not os.path.exists(csv_dir):
            os.mkdir(csv_dir)
        out_csv = f'{os.path.join(csv_dir, video_name)}.csv'

        # Create lists to append results from the video itself
        frame_numbers, mean_colour_list = [], []
        timestamp_list = []
        # From boxes
        x_list, y_list, w_list, h_list, num_detections = [], [], [], [], []
        confidences, class_ids, track_ids = [], [], []
        # From keypoints
        kpt0x_list, kpt1x_list, kpt2x_list, kpt3x_list = [], [], [], []
        kpt0y_list, kpt1y_list, kpt2y_list, kpt3y_list = [], [], [], []
        kpt0_conf, kpt1_conf, kpt2_conf, kpt3_conf = [], [], [], []

    # Load video
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f'Starting to extract results from video {video_name} with a total lenght of {total_frames} frames.')

    if save_csv == True:
        # Open CSV file for writing
        csv_file = open(out_csv, 'w')
        csv_file.write(
            'total_frames,frame,timestamp,mean_color,num_detections,class,confidence,track_id,x,y,w,h,kpt0_x,kpt0_y,kpt1_x,kpt1_y,'
            'kpt2_x,kpt2_y,kpt3_x,kpt3_y,kpt0_conf,kpt1_conf,kpt2_conf,kpt3_conf\n')

    # Iterate through video frames
    frame_number = 1
    while True:
        print(f'Extracting results from {video_name_ext}, frame {frame_number}')

        # Read frame
        ret, frame = cap.read()
        if not ret:
            break  # Break the loop if there are no more frames

        # RUN HERE ALL THE OTHER STEPS TO THE IMAGE (LIKE READ TIMESTAMP)
#_______________________
        if save_csv == True:
            ROIxywh1 = (229, 8, 408 - 227, 24 - 8)
            th1 = 110
            timestamp = read_timestamp(frame, ROIxywh1, th1)
            if len(timestamp) == 0 or timestamp.isdigit() == False:
                ROIxywh2 = (233, 18, 404 - 233, 33 - 18)
                th2 = 150
                timestamp = read_timestamp(frame, ROIxywh2, th2)
                if len(timestamp) == 0 or timestamp.isdigit() == False:
                    timestamp = 'NA'
                    timestamp_list.append(timestamp)
                else:
                    timestamp_list.append(timestamp)
            else:
                timestamp_list.append(timestamp)
                print(f'timestamp is NA in frame {frame} -> {timestamp}')

            # Calculate mean pixel color of the frame
            mean_colour = np.mean(frame)
# _______________________

        # Run inference on the current frame
        results = model.track(frame, conf=0.6, stream=True, persist=True, tracker="botsort.yaml", batch=batch_size)
        #results = model.predict(frame, conf=0.6, stream=True)
        # persist=True tells the tracker that the current image or frame is the next in a sequence and to expect
        # tracks from the previous image in the current image
        # Use stream=True for processing long videos or large datasets to efficiently manage memory.

        # Process results
        for frame, result in enumerate(results):

            if save_csv == True:

                # Define result types
                boxes = result.boxes.cpu().numpy()
                results_keypoint = result.keypoints.xyn.cpu().numpy() # Use xyn for normalized coordinates by image size
                keypoint_confs = result.keypoints.conf

                if len(boxes) > 0:  # If there is a detection in the frame:
                    # Extract boxes
                    for detection in boxes: # For each detection in the frame:
                        class_id = int(detection.cls)
                        conf = float(detection.conf)
                        xywh_str = detection.xywhn
                        track_id = detection.id

                        # Append the results in the lists
                        frame_numbers.append(frame_number)
                        mean_colour_list.append(int(mean_colour))
                        num_detections.append(len(boxes))
                        # Convert track_id from the numpy array to a number when there is an ID, not a "None"
                        if track_id is None:
                            continue
                        else:
                            track_id = int(track_id.flatten()[0])

                        # Extract individual box coordinates from each detection
                        xywh = xywh_str.flatten()

                        if class_id == 0.0:  # If the detection is from a "jackdaw" class
                            x, y, w, h = map(float, xywh[:4])

                            # Append bbox values to lists
                            x_list.append("{:.4f}".format(x))
                            y_list.append("{:.4f}".format(y))
                            w_list.append("{:.4f}".format(w))
                            h_list.append("{:.4f}".format(h))
                            confidences.append("{:.2f}".format(conf))
                            class_ids.append(class_id)
                            track_ids.append(track_id)

                    # Extract keypoints
                    for result_keypoint in results_keypoint: # For each detection in the frame:
                        # Using 4 keypoints per object detected, split keypoints list into list for each object
                        keypoint_chunks = [result_keypoint[x:x + 4] for x in range(0, len(result_keypoint), 4)]

                        for chunk in keypoint_chunks:
                            try:
                                # Append keypoints
                                kpt0x_list.append("{:.4f}".format(chunk[0][0])) # beak
                                kpt1x_list.append("{:.4f}".format(chunk[1][0])) # head
                                kpt2x_list.append("{:.4f}".format(chunk[2][0])) # neck
                                kpt3x_list.append("{:.4f}".format(chunk[3][0])) # tail
                                kpt0y_list.append("{:.4f}".format(chunk[0][1]))
                                kpt1y_list.append("{:.4f}".format(chunk[1][1]))
                                kpt2y_list.append("{:.4f}".format(chunk[2][1]))
                                kpt3y_list.append("{:.4f}".format(chunk[3][1]))
                            except:
                                print(f'No keypoints in this frame')
                    # Extract keypoint confidences
                    for keypoint_conf in keypoint_confs:
                        keypoint_conf_chunk = [keypoint_conf[x:x + 4] for x in range(0, len(keypoint_conf), 4)]

                        for chunk_conf in keypoint_conf_chunk:
                            try:
                                # Append keypoint confidences
                                kpt0_conf.append("{:.2f}".format(chunk_conf[0]))
                                kpt1_conf.append("{:.2f}".format(chunk_conf[1]))
                                kpt2_conf.append("{:.2f}".format(chunk_conf[2]))
                                kpt3_conf.append("{:.2f}".format(chunk_conf[3]))
                            except:
                                print(f'No keypoint confidences in this frame')
                else: # If no detection in the frame:
                    # Append frame information:
                    frame_numbers.append(frame_number)
                    mean_colour_list.append(int(mean_colour))

                    # Append NAs
                    num_detections.append(0)
                    x_list.append('NA')
                    y_list.append('NA')
                    w_list.append('NA')
                    h_list.append('NA')
                    confidences.append('NA')
                    class_ids.append('NA')
                    track_ids.append('NA')
                    kpt0x_list.append('NA')
                    kpt1x_list.append('NA')
                    kpt2x_list.append('NA')
                    kpt3x_list.append('NA')
                    kpt0y_list.append('NA')
                    kpt1y_list.append('NA')
                    kpt2y_list.append('NA')
                    kpt3y_list.append('NA')
                    kpt0_conf.append('NA')
                    kpt1_conf.append('NA')
                    kpt2_conf.append('NA')
                    kpt3_conf.append('NA')

            # Save processed images using openCV
            # if from_frame < frame_number < to_frame: # to save just a part of the video (from_frame:to_frame)
            if save_video == True:
                save_images(frame_number, result, video_name, out_dir)

            # Increment frame number by 1 and continue de loop through video frames
            frame_number += 1

    # Save results in the CSV file
    if save_csv == True:
        for frame_num, time_stamp, mean_col, num_det, x, y, w, h, conf, class_id, track_id, kpt0x, kpt1x, kpt2x, kpt3x, kpt0y, kpt1y, kpt2y, kpt3y, kpt0_c, kpt1_c, kpt2_c, kpt3_c in zip(
                frame_numbers, timestamp_list, mean_colour_list,
                num_detections, x_list, y_list, w_list, h_list, confidences, class_ids, track_ids, kpt0x_list,
                kpt1x_list, kpt2x_list, kpt3x_list, kpt0y_list, kpt1y_list, kpt2y_list, kpt3y_list, kpt0_conf,
                kpt1_conf, kpt2_conf, kpt3_conf):

            # For every frame, write the following string with all the results
            string = (f'{total_frames},{frame_num},{time_stamp},{int(mean_col)},'
                      f'{num_det},{class_id},{conf},{track_id},{x},{y},{w},{h},{kpt0x},{kpt0y},{kpt1x},{kpt1y},'
                      f'{kpt2x},{kpt2y},{kpt3x},{kpt3y},{kpt0_c},{kpt1_c},{kpt2_c},{kpt3_c}\n')
            csv_file.write(string)

    print(f'{out_csv} created successfully')

    # Release video capture object
    cap.release()

    # Save video if "save_video" argument is True
    if save_video:
        processed_vid_dir = os.path.join(out_dir, 'processed_videos')
        frames_dir = os.path.join(out_dir, f'frames', video_name)
        if not os.path.exists(processed_vid_dir):
            os.mkdir(processed_vid_dir)
        jpgtovid(frames_dir, processed_vid_dir, 1)
        # IF RUN IN LINUX, CONVERT FRAMES TO VIDEO USING FFMPEG INSTEAD OF OPENCV
        #ffmpeg_imgtovid(frames_dir, processed_vid_dir)
        #shutil.rmtree(frames_dir)

def process_video(vid):
    # Add your processing logic here for a single video
    weights_path = "yolov8m_custom_pose.pt"
    out_dir = "your_results_directory"
    run_yolo_inference(weights_path, vid, out_dir, save_csv=True, save_video=False)

if __name__ == "__main__":
    # Pose model path
    weights_path = "yolov8m_custom_pose.pt"
    # Directory with all the videos to run inference on
    video_dir = r"your_videos_directory"
    # Directory to save the results in CSV and frames if "save_images" function is not commented
    out_dir = "your_results_directory"

    video_list = sorted(os.listdir(video_dir))
    print(f'Starting the conversion of videos in {video_dir}')
    print(f'First video is: {video_list[0]}')

    # # Run YOLO inference
    for vid in sorted(video_list):
        vid = os.path.join(video_dir, vid)
        if not os.path.exists(os.path.join(out_dir, 'processed_csv', f'{os.path.split(vid)[1][:-4]}.csv')):
            if not os.path.exists(os.path.join(out_dir, 'processed_csv')):
                os.mkdir(os.path.join(out_dir, 'processed_csv'))
                print(f"Directory created successfuly: {os.path.join(out_dir, 'processed_csv')}")
            run_yolo_inference(weights_path, vid, out_dir, save_csv=True, save_video=True)
        else: print(f'Path already exists: Skipping video {vid}')


    # Use concurrent.futures to parallelize video processing

    # with concurrent.futures.ProcessPoolExecutor() as executor:
    #     futures = [executor.submit(process_video, os.path.join(video_dir, vid)) for vid in video_list]
    #     for future in concurrent.futures.as_completed(futures):
    #         try:
    #             future.result()  # This will raise any exceptions from the thread if they occur
    #         except Exception as e:
    #             print(f"Error processing video: {e}")