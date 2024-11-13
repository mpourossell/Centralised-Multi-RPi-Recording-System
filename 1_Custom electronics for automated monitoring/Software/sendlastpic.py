# This script sends the last recorded picture to your e-mail. It's used to manually check that the camera
# is well positioned and the recording is doing well.

import glob
import os
import yagmail
import socket
import config

list_of_recs = glob.glob("/home/pi/pirecorder/recordings/*") # * means all if need specific format then *.csv 
latest_rec = max(list_of_recs, key=os.path.getmtime) 
print("Latest_rec is " + latest_rec) 
latest_pic = max(glob.glob(latest_rec + "/*.jpg"), key=os.path.getmtime)
# start a connection with GMAIL
FROM = config.gmail_address
password = config.gmail_password
yag = yagmail.SMTP(FROM, password)
# define the variables
to = config.gmail_address
subject = "LastPic " + socket.gethostname() 
contents = [yagmail.inline(latest_pic)]
# send email
yag.send(to, subject, contents)
