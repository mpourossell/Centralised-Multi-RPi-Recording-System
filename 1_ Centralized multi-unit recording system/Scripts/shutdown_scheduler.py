# This script is used to schedule the shutdown based on daylight.

from astral.sun import sun
from astral import LocationInfo
import pytz
from datetime import timedelta
import datetime
from crontab import CronTab
import socket
import config

def get_sunrise_sunset(lat, long, date_=None):
    location = LocationInfo(lat, long)
    local_timezone = pytz.timezone(config.timezone)

    # If no date is provided, use today's date
    if date_ is None:
        date_ = datetime.datetime.now()

    # Calculate sunrise and sunset times
    s = sun(location.observer, date=date_)

    # Return the local time of sunrise, sunset, and twilight
    return (
        s['sunrise'].astimezone(local_timezone),
        s['sunset'].astimezone(local_timezone)
    )

# Update cron job to turn ON or OFF the GPIO pins

latitude = config.latitude
longitude = config.longitude

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(latitude, longitude)
if socket.gethostname() == config.parent_hostname:
    shutdown_time = sunset + timedelta(hours=config.extra_hours) + timedelta(minutes=config.extra_minutes) # Shutdown time delayed in the parent RPi
else:
    shutdown_time = sunset + timedelta(hours=config.extra_hours)
print(f'sunset = {sunset}. shutdown_time = {shutdown_time}')
command_shut = "sleep 360 && sudo shutdown -h now"
# Get the user's crontab
cron = CronTab(user=True)
#looking for the job using the comment
exists = False

for job in cron:
    # Find Shutdown
    if job.comment == 'Shutdown':
        job.minute.on(shutdown_time.minute)
        job.hour.on(shutdown_time.hour)
        cron.write()
        exists = True

# Create a new shitdown job if it does not exist
if exists == False:
    job_shut = cron.new(command=command_shut)
    #adding comment on the job
    job_shut.set_comment('Shutdown')
    job_shut.minute.on(shutdown_time.minute)
    job_shut.hour.on(shutdown_time.hour)
    cron.write()
    print(f"New shutdown cron job scheduled at {shutdown_time}")
else:
    print(f"Modified shutdown cron job scheduled at {shutdown_time}")