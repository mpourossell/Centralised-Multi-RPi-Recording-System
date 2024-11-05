import cv2
import torch
import pandas as pd
import os
import numpy as np
import re
from datetime import datetime
from ultralytics import YOLO
import glob
import ffmpeg
import shutil


def jpgtovid(output_video_path, in_dir, fps):
    print(f'Starting conversion of: {in_dir}')
    img_array = []
    for filename in glob.glob(os.path.join(in_dir, '*.jpg')):
        #print(f'Working on file: {filename}')
        img = cv2.imread(filename)
        height, width, layers = img.shape
        size = (width, height)
        img_array.append(img)
    video = cv2.VideoWriter(output_video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (640, 480))
    for i in range(len(img_array)):
        video.write(img_array[i])
    video.release()
    print('Video "' + output_video_path + ' created successfully :D')


def ffmpeg_imgtovid(temp_frame_folder, output_video_path, fps):
    video = (ffmpeg
             .input(os.path.abspath(temp_frame_folder + '\%05.jpg'), framerate=fps)
             .output(output_video_path, vcodec='libx264', pix_fmt='yuv420p')
             .run()
             )


def annotate_video_from_csv(csv_path, input_video_path, output_video_path, fps):
    print(f"Annotating video {output_video_path}...")
    cap = cv2.VideoCapture(input_video_path)
    frame_width, frame_height = int(cap.get(3)), int(cap.get(4))
    out = cv2.VideoWriter(output_video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (frame_width, frame_height))

    # Load detection data
    detections = pd.read_csv(csv_path)

    # Define keypoint names and colors
    keypoint_colors = {
        0: (255, 0, 0),  # Dark purple
        1: (255, 127, 0),  # Yellow
        2: (255, 255, 0),  # Orange-red
        3: (0, 255, 0)  # Dark green
    }

    frame_num = 1
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        print(f"Working on frame {frame_num}")
        # Get detections for current frame
        frame_detections = detections[detections['frame'] == frame_num]

        for _, row in frame_detections.iterrows():
            if row[['x', 'y', 'w', 'h']].isnull().any():
                continue  # Skip if any bounding box values are NaN

            # Draw bounding box
            x, y, w, h = row['x'] * frame_width, row['y'] * frame_height, row['w'] * frame_width, row[
                'h'] * frame_height
            cv2.rectangle(frame,
                          (int(x - w / 2), int(y - h / 2)),
                          (int(x + w / 2), int(y + h / 2)),
                          (15, 15, 230), 2)

            info_text = (f"Frame: {row['frame']} | Timestamp: {row['timestamp']} | Mean Color: {row['mean_col']}")
            cv2.putText(frame, info_text, (10, 450), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

            # Prepare text for confidence and id
            label = f"ID: {row['track_id']}, Conf: {row['conf']:.2f}"
            label_pos = (int(x * frame_width - w * frame_width / 2),
                         int(y * frame_height - h * frame_height / 2) - 7)

            # Draw the label text
            cv2.putText(
                frame,
                label,
                label_pos,
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (255, 255, 255),  # White text color
                1,  # Thickness
                lineType=cv2.LINE_AA
            )

            # Collect non-zero keypoints for line drawing
            keypoints = [(row[f"keypoint_{i}_x"] * frame_width, row[f"keypoint_{i}_y"] * frame_height) for i in
                         range(4)]
            non_zero_keypoints = [(int(kp[0]), int(kp[1]), i) for i, kp in enumerate(keypoints) if kp != (0, 0)]

            # Draw individual keypoints
            for kp_x, kp_y, i in non_zero_keypoints:
                cv2.circle(frame, (kp_x, kp_y), 4, keypoint_colors[i], -1)

            # Draw lines connecting all non-zero keypoints
            for i in range(len(non_zero_keypoints) - 1):
                cv2.line(frame, non_zero_keypoints[i][:2], non_zero_keypoints[i + 1][:2], (0, 0, 0), 1)

        out.write(frame)
        frame_num += 1

    cap.release()
    out.release()


def run_yolo_inference(weights_path, input_video_folder, timestamp_folder, output_directory, save_video=False, save_csv=True):
    output_csv_folder = os.path.join(output_directory, "inference_csv")
    if save_csv == True:
        if not os.path.exists(output_csv_folder):
            os.mkdir(output_csv_folder)
    if save_video == True:
        output_video_folder = os.path.join(output_directory, "inference_videos")
        if not os.path.exists(output_video_folder):
            os.mkdir(output_video_folder)

    # Load YOLOv8 model under CUDA
    torch.cuda.set_device(0)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    # Load YOLO model
    model = YOLO(weights_path)
    model.to(device=device)
    print('Working under device: ', model.device.type)

    # Process each video
    for video_name in sorted(os.listdir(input_video_folder)):
        video_path = os.path.join(input_video_folder, video_name)
        timestamp_path = os.path.join(timestamp_folder, f"{os.path.splitext(video_name)[0]}.txt")
        output_csv_path = os.path.join(output_csv_folder, f"{os.path.splitext(video_name)[0]}_detections.csv")
        output_video_path = os.path.join(output_video_folder, f"{os.path.splitext(video_name)[0]}_infered.mp4")
        if os.path.exists(output_csv_path):
            if not os.path.exists(output_video_path):
                annotate_video_from_csv(output_csv_path, video_path, output_video_path, fps=1)
                continue
            else:
                continue

        # Read timestamps
        with open(timestamp_path, 'r') as f:
            timestamps = [line.strip() for line in f.readlines()]
            timestamps = sorted(timestamps)

        # Prepare video input and output
        cap = cv2.VideoCapture(video_path)
        frame_width, frame_height = int(cap.get(3)), int(cap.get(4))
        #print(f'frame w h = {frame_width}, {frame_height}')
        fps = cap.get(cv2.CAP_PROP_FPS)
        #print(f'FPS = {fps}')
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        #print(f'Total frames = {total_frames}')

        if save_csv == True:
            # Prepare dataframe for CSV output
            detection_data = []

        frame_num = 1
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            #if os.path.exists(os.path.join(temp_frame_folder, f"{frame_num:05d}.jpg")):
            #    print(f'Skipping {video_name} frame: {frame_num}. {frame_num:05d}.jpg already exists!')
            #    frame_num +=1
            #    continue
            print(f'Processing {video_name} frame: {frame_num}')
            # RUN HERE ALL THE OTHER STEPS TO THE IMAGE (LIKE READ TIMESTAMP)
            # _______________________

            # Find timestamp of the current frame
            match = re.search(r"(\d{6})_(\d{6})", timestamps[frame_num - 1])
            if match:
                date_part = match.group(1)
                time_part = match.group(2)

                # Parse date and time parts and format to "YYYY-MM-DD HH:MM:SS"
                datetime_str = datetime.strptime(date_part + time_part, "%y%m%d%H%M%S")
                timestamp = datetime_str.strftime("%Y-%m-%d %H:%M:%S")
                print(f'Timestamp in frame {frame_num} = {timestamp}')

            else:
                print("Date and time not found in this frame.")

            # Calculate mean pixel color of the frame
            mean_color = np.mean(frame)
            mean_color = round(mean_color, 2)
            # _______________________

            # Run inference
            results = model.track(frame, conf=0.5, show=False, tracker="botsort.yaml", )
            for result in results:
                # Define result types
                boxes = result.boxes.cpu().numpy()
                results_keypoint = result.keypoints.cpu().numpy()  # Use xyn for normalized coordinates by image size
                # Track number of detections in this frame
                num_detections = len(boxes) if boxes is not None else 0

                info_text = (f"Frame: {frame_num} | Timestamp: {timestamp} | Mean Color: {mean_color}")
                cv2.putText(frame, info_text, (10, 450), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

                # If there are detections, process each detection individually
                if num_detections > 0:
                    for box, keypoints in zip(boxes, results_keypoint):
                        track_id = box.id
                        if track_id is None:
                            continue
                        else:
                            track_id = int(track_id.flatten()[0])
                        x, y, w, h = box.xywhn[0]
                        conf = float(box.conf)
                        conf = round(conf, 2)

                        # Extract keypoints (beak, head, neck, tail)
                        keypoint_coords = keypoints.xyn[0]
                        keypoint_coords = keypoint_coords.tolist()
                        keypoint_conf = keypoints.conf[0]
                        keypoint_conf = keypoint_conf.tolist()

                        if save_csv == True:
                            # Add detection information to the data list
                            detection_data.append({
                                "frame": frame_num,
                                "timestamp": timestamp,
                                "mean_col": mean_color,
                                "num_detections": num_detections,
                                "track_id": round(track_id),
                                "x": round(x, 6),
                                "y": round(y, 6),
                                "w": round(w, 6),
                                "h": round(h, 6),
                                "conf": conf,
                                **{f"keypoint_{i}_x": round(keypoint[0], 6) for i, keypoint in enumerate(keypoint_coords)},
                                **{f"keypoint_{i}_y": round(keypoint[1], 6) for i, keypoint in enumerate(keypoint_coords)},
                                **{f"keypoint_{i}_conf": round(keypoint, 2) for i, keypoint in enumerate(keypoint_conf)}

                            })
                        if save_video == True:
                            # Draw bounding box and keypoints on frame
                            cv2.rectangle(frame,
                                          (int(x*frame_width - w*frame_width / 2), int(y*frame_height - h*frame_height / 2)),
                                          (int(x*frame_width + w*frame_width / 2), int(y*frame_height + h*frame_height / 2)),
                                          (15, 15, 230), 2)

                            # Prepare text for confidence and id
                            label = f"ID: {track_id}, Conf: {conf:.2f}"
                            label_pos = (int(x * frame_width - w * frame_width / 2),
                                         int(y * frame_height - h * frame_height / 2) - 7)

                            # Draw the label text
                            cv2.putText(
                                frame,
                                label,
                                label_pos,
                                cv2.FONT_HERSHEY_SIMPLEX,
                                0.5,
                                (255, 255, 255),  # White text color
                                1,  # Thickness
                                lineType=cv2.LINE_AA
                            )

                            keypoint_colors = {
                                "beak": (68, 1, 84),  # Dark purple
                                "head": (253, 231, 36),  # Yellow
                                "neck": (240, 59, 32),  # Orange-red
                                "tail": (0, 170, 88)  # Dark green
                            }

                            # Normalize colors to the range [0, 255]
                            keypoint_colors = {k: tuple(int(c) for c in v) for k, v in keypoint_colors.items()}

                            keypoint_indices = ['beak', 'head', 'neck', 'tail']
                            previous_keypoint = None
                            valid_keypoints = []

                            for i, kp_set in enumerate(keypoint_coords):
                                kp_x, kp_y = kp_set[0], kp_set[1]
                                if (kp_x, kp_y) != (0, 0):  # Skip keypoints at (0, 0)
                                    valid_keypoints.append((kp_x * frame_width, kp_y * frame_height, keypoint_indices[i],
                                                            keypoint_colors[keypoint_indices[i]]))

                                color = keypoint_colors.get(keypoint_indices[i], (0, 255, 255))  # Yellow for unknown
                                for i, (x, y, name, color) in enumerate(valid_keypoints):
                                    cv2.circle(frame, (int(kp_x * frame_width), int(kp_y * frame_height)), 4, color, -1)

                                    if i > 0:
                                        prev_x, prev_y, _, _ = valid_keypoints[i - 1]
                                        cv2.line(frame, (int(prev_x), int(prev_y)), (int(x), int(y)), (0, 0, 0),
                                                 1)  # Draw line between keypoints

                else:
                    if save_csv == True:
                        # Add a row with NA values for frames without detections
                        detection_data.append({
                            "frame": frame_num,
                            "timestamp": timestamp,
                            "mean_col": mean_color,
                            "num_detections": 0,
                            "track_id": np.nan,
                            "x": np.nan,
                            "y": np.nan,
                            "w": np.nan,
                            "h": np.nan,
                            "conf": np.nan,
                            **{f"keypoint_{i}_x": np.nan for i in range(4)},
                            **{f"keypoint_{i}_y": np.nan for i in range(4)},
                            ** {f"keypoint_{i}_conf": np.nan for i in range(4)}

                        })
                cv2.imshow("Frame", frame)

                # Wait for a key press; you can specify a delay in milliseconds (0 for indefinite wait)
                if cv2.waitKey(1) & 0xFF == ord('q'):  # Press 'q' to exit
                    break

            frame_num += 1

        if save_csv == True:
            # Save CSV with detection information
            if not os.path.exists(output_csv_folder):
                os.mkdir(output_csv_folder)
            pd.DataFrame(detection_data).to_csv(output_csv_path, index=False)

        # Release video resources
        cap.release()
        cv2.destroyAllWindows()

        if save_video == True:
            annotate_video_from_csv(output_csv_path, video_path, output_video_path, fps=1)
            print(f"Saving complete: {output_video_path}")

    print("Inference and saving complete.")




# Example usage


if __name__ == "__main__":
    # Define paths
    weights_path = r"E:\2024\yolov8m-pose_custom.pt"
    video_folder = r"E:\2024\videos_ALL"
    timestamp_folder = r"E:\2024\lists_ALL"
    output_directory = r"E:\2024\YOLO_output"


    run_yolo_inference(weights_path, video_folder, timestamp_folder, output_directory, save_video=True, save_csv=True)