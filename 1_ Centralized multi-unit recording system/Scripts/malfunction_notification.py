# This script checks for errors in the system and notifies via gmail when detected. It can be
# customized as needed, adding functions to check other components of the system.
# It can be scheduled using cron.

import cv2
import glob
import os
import logging
import yagmail
import socket
import datetime
import config

# start a connection with GMAIL
FROM = config.gmail_address
yag = yagmail.SMTP(FROM, config.gmail_password)

# define the variables
to = config.gmail_address
subject = socket.gethostname() + " ERROR!"

# Set logging parameters
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
file_handler = logging.FileHandler("Malfunction" + socket.gethostname() + ".log")
formatter = logging.Formatter("%(asctime)s:%(name)s:%(message)s")
file_handler.setFormatter(formatter)
stream_handler = logging.StreamHandler()
stream_handler.setFormatter(formatter)
logger.addHandler(file_handler)
logger.addHandler(stream_handler)

now = datetime.datetime.now()
date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
body = []

try:
    # Find the last picture captured by Pi Recorder
    list_of_recs = glob.glob("/home/pi/pirecorder/recordings/*")  # * means all if need specific format then *.jpg...
    latest_rec = max(list_of_recs, key=os.path.getmtime)
    logger.debug("Latest_rec is " + latest_rec)
except:
    latest_rec = None
    logger.debug(datetime.datetime.now() + ": Recordings folder is EMPTY")
    body.append(socket.gethostname() + " ERROR! Pirecorder/Recordings folder is EMPTY!")

try:
    latest_pic = max(glob.glob(latest_rec + "/*.jpg"), key=os.path.getmtime)
    logger.debug("Latest_pic is " + latest_pic)
except:
    latest_pic = None
    logger.debug(latest_rec + " folder is EMPTY")
    body.append(socket.gethostname() + " ERROR! NO pictures in " + latest_rec + " folder!")

# Load the picture in PIL_Image
if latest_pic:
    try:
        file_size = os.path.getsize(latest_pic)
        # Check if image size is 0
        if file_size == 0:
            logger.debug("Image damaged! Byte = 0")
            # send the email
            body.append(socket.gethostname() + " ERROR! Capturing damaged images! File size = 0bytes")
        else:
            logger.debug("Latest_pic size is: " + str(file_size / 1000) + " Kb. (" + latest_pic + ")")
            image = cv2.imread(latest_pic, 0)
            blur = cv2.blur(image, (5, 5))  # With kernel size depending upon image size
            if cv2.mean(blur) > (
            20, 20, 20, 20):  # The range for a pixel's value in grayscale is (0-255), 127 lies midway
                logger.debug("LED is working correctly")  # (127 - 255) denotes light image
            else:
                logger.debug("ERROR! Recording almost black images...")  # (0 - 127) denotes dark image
                body.append(socket.gethostname() + " ERROR! Recording almost black images... LED might not be working correctly")
    except:
        logger.debug(latest_rec + " folder is EMPTY")
        body = socket.gethostname() + " ERROR! Pirecorder/Recordings folder is EMPTY!"

if latest_rec:

    c_date = os.path.getctime(latest_rec)
    cdate = datetime.datetime.fromtimestamp(c_date)
    date = cdate.strftime("%d-%m-%Y")
    now = datetime.datetime.now()

    if date != now.strftime("%d-%m-%Y"):
        logger.debug("ERROR! Today is not recording")
        body.append(socket.gethostname() + " ERROR! Today is not recording")

if body:
    bodystr = ' '.join(body)
    if config.notification == True:
        yag.send(to, subject, bodystr)
else:
    pass