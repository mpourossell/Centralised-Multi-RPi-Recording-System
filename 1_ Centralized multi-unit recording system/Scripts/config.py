# This script is used to define key initial configurations

import socket

# Set timezone where the system is installed
timezone = 'Europe/Madrid'

# Set exact coordinates of system installation
latitude = 41.617592
longitude = 0.620015

# Set system working schedules
## Time to wake-up before sunrise (in hours)
extra_hours = 2
extra_minutes = 10

# Email address for notification
gmail_address = 'your@gmail.com'
gmail_password = 'yourpassword'

# Activate of deactivate malfunction notification via Email (True/False)
notification = True

# Select folder where data will be uploaded for backup (after mounting google Drive to the RPi)
targ_dir = f'/home/pi/mnt/gdrive/RPi_videos/{socket.gethostname()}'

# Web server for real-time status monitoring
# Set username and password to access the web server for more seccurity
web_login_username = 'yourusername'
web_login_password = 'yourpassword'
# Unique domain generated with Ngrok, where the data will be uploaded to the internet
web_server_domain = 'yourdomain'

# If using multiple units, set the "parent" computer hostname. We recommend to use names in sequence such as "rpi00" for the parent, "rpi01", "rpi02"... for the child units.
parent_hostname = 'hostname'