# This script converts image sequences to video using ffmpeg. It compresses the video.
# It also logs debugger for error control.

import socket
import logging
import glob
import os
import datetime
import ffmpeg
import cv2
import fnmatch

# Set logging parameters
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
file_handler = logging.FileHandler("ffmpeg_imgtovid_" + socket.gethostname() + ".log")
formatter = logging.Formatter("%(asctime)s:%(name)s:%(message)s")
file_handler.setFormatter(formatter)
stream_handler = logging.StreamHandler()
stream_handler.setFormatter(formatter)
logger.addHandler(file_handler)
logger.addHandler(stream_handler)

#Define the function that will convert the subdirectories of the main directory to a video.
#The arguments are the main directory where folders with image sequences are stored
# and the directory where output videos should be stored
def imgtovid(main_dir, out_dir):

    #Create a list of subdirectories in the main directory
    list_of_recs = sorted(glob.glob(main_dir + '/*')) # the '*' means all formats. If need specific format, then '*.jpg' i.e.

    #Start loop to do the function to all subdirectories in the main_dir
    for directories in list_of_recs:
        sub_path = os.path.split(directories)[0]
        sub_dir = os.path.split(directories)[1]
        outvid = os.path.join(out_dir, sub_dir + '.avi')

        if os.path.exists(outvid) == False:
            c_date = os.path.getctime(directories)
            cdate = datetime.datetime.fromtimestamp(c_date)
            date = cdate.strftime("%d-%m-%Y")
            now = datetime.datetime.now()

            if date != now.strftime("%d-%m-%Y"):
                #print(f'Working on file: {sub_path + sub_dir} --> Starting conversion...')
                if len(fnmatch.filter(os.listdir(directories), "*.*")) < 300: #if recording is less than 500 frames
                    try:
                        video = (ffmpeg
                                .input(os.path.abspath(directories + '/*.jpg'), pattern_type='glob', framerate=1)
                                .output(outvid, vcodec='libx264', pix_fmt='yuv420p')
                                .run()
                                )
                        logger.DEBUG("SUCCESS: Video " + sub_dir + ".avi" + " succesfully converted")
                    except:
                        logger.DEBUG("ERROR in conversion: Broken files in " + sub_dir + " directory.")
                else:
                    try:
                        video = (ffmpeg
                                .input(os.path.abspath(directories + '/*.jpg'), pattern_type='glob', framerate=120)
                                .output(outvid, vcodec='libx264', pix_fmt='yuv420p')
                                .run()
                                )
                        logger.DEBUG("SUCCESS: Video " + sub_dir + ".avi" + " succesfully converted")
                    except:
                        pass
            else:
                pass #print("SKIPPING CONVERSION: " + sub_dir + ' recording still runing...')
        else:
            #print("Working on: " + sub_path + sub_dir + ' --> Starting conversion...')
            #Count number of frames of already existing video
            cap = cv2.VideoCapture(outvid)
            vidframes = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            #Count number of frames of recording directory
            dirframes = len(fnmatch.filter(os.listdir(directories), "*.*"))
            #print("Frames in Video " + sub_dir + "  = " + str(vidframes))
            #print("Frames in folder " + sub_dir + "  = " + str(dirframes))
            if vidframes < (dirframes - 60):
                video = (ffmpeg
                         .input(os.path.abspath(directories + '/*.jpg'), pattern_type='glob', framerate=120)
                         .output(outvid, vcodec='libx264', pix_fmt='yuv420p')
                         .run(overwrite_output=True)
                         )
                logger.DEBUG("RECONVERSION: Video " + sub_dir + ".avi" + " succesfully reconverted")
            else:
                pass #print('file ' + outvid + ' already exists. Skipping conversion.')

if __name__ == '__main__':
    main_dir = '/home/pi/pirecorder/recordings'
    out_dir = '/home/pi/Videos'
    imgtovid(main_dir, out_dir)
