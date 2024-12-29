# This script reads random sections of random videos and allow to manually annotate false detections
# and missed detections. It automatically stores the results in a csv file that we can later quantify
# reliability with. It also allows multiple annotation sessions, so no need to do it continuously!

import cv2
import pandas as pd
import random
import csv
import os


def get_video_and_detection_files(video_dir, detection_dir):
    """Selects a random video and its corresponding detection CSV file."""
    videos = [f for f in os.listdir(video_dir) if f.endswith(('.mp4', '.avi', '.mov'))]  # Add more formats as needed
    selected_video = random.choice(videos)
    video_path = os.path.join(video_dir, selected_video)

    # Generate the expected CSV filename
    csv_filename = f"{os.path.splitext(selected_video)[0]}_processed.csv"
    detection_csv_path = os.path.join(detection_dir, csv_filename)

    # Check if the detection CSV file exists
    if os.path.exists(detection_csv_path):
        return video_path, detection_csv_path
    else:
        print(f"No detection CSV found for {selected_video}.")
        return None, None


def load_existing_annotations(annotation_csv_path):
    if os.path.exists(annotation_csv_path):
        return pd.read_csv(annotation_csv_path)
    return pd.DataFrame(columns=['video', 'frame', 'error_type'])


def get_total_frames(video_path):
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()
    return total_frames, fps


# def select_random_segment(total_frames, fps, duration=30):
#     start_frame = random.randint(0, max(0, total_frames - duration * fps))
#     end_frame = start_frame + duration * fps
#     return start_frame, end_frame

def get_video_and_csv_pairs(video_dir, detection_csv_dir):
    video_files = []
    for video_file in os.listdir(video_dir):
        if video_file.endswith(('.mp4', '.avi', '.mov')):  # Adjust file types as needed
            video_path = os.path.join(video_dir, video_file)
            csv_file = video_file.replace('.mp4' or '.avi', '_processed.csv')
            detection_csv_path = os.path.join(detection_csv_dir, os.path.basename(csv_file))

            if os.path.exists(detection_csv_path):
                video_files.append(video_path)

    return video_files


def select_random_segment(total_frames, fps, existing_annotations, video_name, duration=1):
    total_frames = int(total_frames)
    fps = int(fps)
    print(f'FPS = {fps}')

    # Get frames that have already been annotated
    annotated_frames = set(existing_annotations[existing_annotations['video'] == video_name]['frame'])

    # Calculate the possible range for start frames, ensuring no overlap with annotated frames
    valid_start_frames = [
        start_frame for start_frame in range(max(0, total_frames - duration * fps))
        if all(start_frame + offset not in annotated_frames for offset in range(duration * fps))
    ]

    if not valid_start_frames:
        print("No valid segments available for selection.")
        return None, None

    start_frame = random.choice(valid_start_frames)
    end_frame = start_frame + duration * fps
    return start_frame, end_frame


def draw_bounding_boxes_and_keypoints(frame, detections):
    frame_height, frame_width, _ = frame.shape  # Get frame dimensions

    for idx, row in detections.iterrows():
        # Check for NaN values and skip if any of the bounding box values are missing
        if pd.isna(row['x']) or pd.isna(row['y']) or pd.isna(row['w']) or pd.isna(row['h']):
            print(f"Skipping detection with missing values at index {row['frame']}")
            continue

        # Denormalize the center coordinates and box dimensions
        x_center = row['x'] * frame_width
        y_center = row['y'] * frame_height
        w = row['w'] * frame_width
        h = row['h'] * frame_height

        # Calculate the top-left corner of the bounding box
        x_top_left = int(x_center - w / 2)
        y_top_left = int(y_center - h / 2)

        # Draw the bounding box
        color = (0, 255, 0)  # Green for bounding box
        cv2.rectangle(frame, (x_top_left, y_top_left), (int(x_top_left + w), int(y_top_left + h)), color, 2)

        # Draw keypoints if they are present
        keypoints = []
        for i in range(4):
            kpt_x, kpt_y, kpt_conf = row.get(f'kpt{i}_x'), row.get(f'kpt{i}_y'), row.get(f'kpt{i}_conf')
            if not pd.isna(kpt_x) and not pd.isna(kpt_y) and kpt_conf > 0.5:  # Check for valid keypoints
                # Denormalize keypoints as well
                kpt_x = int(kpt_x * frame_width)
                kpt_y = int(kpt_y * frame_height)
                keypoints.append((kpt_x, kpt_y))
                cv2.circle(frame, (kpt_x, kpt_y), 5, (0, 0, 255), -1)  # Red circle for keypoints

        # Draw lines between keypoints
        if len(keypoints) > 1:
            for i in range(len(keypoints) - 1):
                cv2.line(frame, keypoints[i], keypoints[i + 1], (255, 0, 0), 2)  # Blue lines between keypoints

    return frame


def annotate_detections(video_path, detection_csv_path, annotation_csv_path):
    # Load detections
    detections_df = pd.read_csv(detection_csv_path)

    # Get total frames in video
    total_frames, fps = get_total_frames(video_path)

    # Load existing annotations
    existing_annotations = load_existing_annotations(annotation_csv_path)

    # Try to find an unannotated segment, with a maximum of 10 attempts
    attempts = 0
    max_attempts = 10
    while attempts < max_attempts:
        start_frame, end_frame = select_random_segment(total_frames, fps, existing_annotations,
                                                       os.path.basename(video_path))

        if start_frame is not None:
            break

        attempts += 1

    if start_frame is None:
        print("No valid segment to analyze.")
        return

    # Open video
    cap = cv2.VideoCapture(video_path)
    current_frame = start_frame
    annotations = []
    displayed_frames = []  # To keep track of all displayed frames

    try:
        while True:
            # Read the frame
            cap.set(cv2.CAP_PROP_POS_FRAMES, current_frame)
            ret, frame = cap.read()
            if not ret:
                break

            # Add the current frame to displayed frames
            displayed_frames.append(current_frame)

            # Display frame info
            if current_frame in detections_df['frame'].values:
                frame_info = detections_df[detections_df['frame'] == current_frame]
                mean_color = frame_info['mean_color'].values[0]

                # Filter the detections for the current frame
                frame_detections = detections_df[detections_df['frame'] == current_frame]

                # Draw bounding boxes, keypoints, confidence, and track ID
                draw_bounding_boxes_and_keypoints(frame, frame_detections)

                cv2.putText(frame, f"Frame: {current_frame}, Mean Color: {mean_color}",
                            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            else:
                cv2.putText(frame, f"Frame: {current_frame} (No detections)",
                            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

            cv2.imshow("Video", frame)
            # Capture keypress for annotation and navigation
            key = cv2.waitKey(0) & 0xFF
            if key == ord('m'):  # Press 'm' for missed detection
                annotations.append(
                    {'error_type': 'missed', 'video': os.path.basename(video_path), 'frame': current_frame})
                print(f'Missed detection on frame {current_frame}')
            elif key == ord('f'):  # Press 'f' for false detection
                annotations.append(
                    {'error_type': 'false', 'video': os.path.basename(video_path), 'frame': current_frame})
                print(f'False detection on frame {current_frame}')
            elif key == ord('d'):  # Right arrow to move forward in the frames
                current_frame += 1
                annotations.append(
                    {'error_type': 'none', 'video': os.path.basename(video_path), 'frame': current_frame})
            elif key == ord('a'):  # Left arrow to move backward in the frames
                current_frame = max(segment_start_frame, current_frame - 1)
            elif key == 27:  # ESC key to quit early
                break

    except Exception as e:
        print("An error occurred:", e)

    finally:
        # Release video capture and save annotations
        cap.release()
        cv2.destroyAllWindows()

        # Save annotations to CSV
        if os.path.exists(annotation_csv_path):
            existing_annotations = pd.read_csv(annotation_csv_path)
            annotations_df = pd.DataFrame(annotations)
            annotations_df = pd.concat([existing_annotations, annotations_df], ignore_index=True)
        else:
            annotations_df = pd.DataFrame(annotations, columns=['video', 'frame', 'error_type'])

        annotations_df.to_csv(annotation_csv_path, index=False)


def compute_detection_metrics(detections_csv, annotations_csv):
    """
    Computes detection accuracy metrics based on manual annotations.
    :param detections_csv: Path to the CSV file with detections
    :param annotations_csv: Path to the CSV file with manual annotations
    """
    # Load the detections and annotations
    detections_df = pd.read_csv(detections_csv)
    annotations_df = pd.read_csv(annotations_csv)

    total_frames = len(annotations_df['frame'].unique())

    # False positives and false negatives
    false_detections = annotations_df[annotations_df['error_type'] == 'false']
    missed_detections = annotations_df[annotations_df['error_type'] == 'missed']

    # Metrics calculations
    total_false_positives = len(false_detections)
    total_false_negatives = len(missed_detections)
    total_correct_detections = total_frames

    precision = total_correct_detections / (
                total_correct_detections + total_false_positives) if total_frames > 0 else 0
    recall = total_correct_detections / (
                total_correct_detections + total_false_negatives) if total_correct_detections > 0 else 0

    # Print the results
    print(f"Total Detections: {total_detections}")
    print(f"False Positives: {total_false_positives}")
    print(f"Missed Detections: {total_false_negatives}")
    print(f"Precision: {precision:.2f}")
    print(f"Recall: {recall:.2f}")

    return precision, recall

if __name__ == "__main__":

    # Example usage:
    video_dir = "videos_directory"  # Video file path
    detection_csv_dir = "extracted_detections_directory"  # CSV file with detections
    annotation_csv_path = "manual_annotations.csv"  # Path to save manual annotations

    video_files = get_video_and_csv_pairs(video_dir, detection_csv_dir)
    print(video_files)

    max_attempts = 10  # Maximum attempts to find a valid video

    for attempt in range(max_attempts):
        if not video_files:
            print("No valid videos left to process.")
            break

        # Randomly select a video
        video_file = random.choice(video_files)
        print(f'Validating detections in >> {video_file} <<')

        # Construct paths
        video_path = video_file  # video_file is a tuple (video_path, detection_csv_path)
        csv_file = video_file.replace('.mp4' or '.avi', '_processed.csv')
        detection_csv_path = os.path.join(detection_csv_dir, os.path.basename(csv_file))
        print(f'video_path = {video_path}')
        print(f'detection_csv_path = {detection_csv_path}')


        try:
            # Annotate detections in the selected video
            annotate_detections(video_path, detection_csv_path, annotation_csv_path)

            # If successful, you can choose to remove the video from the list
            # video_files.remove(video_file)
            break  # Exit loop if annotation was successful

        except Exception as e:
            print(f"Error occurred while processing {video_path}: {e}")
            # Optionally, you can remove the video from the list if you want to avoid retrying it
            # video_files.remove(video_file)

    # Compute metrics based on annotations after completing the process (uncomment if wanted to compute metrics already)
    #compute_detection_metrics(detection_csv_path, annotation_csv_path)