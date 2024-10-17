#!/bin/python

from astral.sun import sun
from astral import LocationInfo
from datetime import date, time, timezone, timedelta
import datetime
from crontab import CronTab

def get_sunrise_sunset(lat, long, date_=None):
    location = LocationInfo(lat, long)

    # If no date is provided, use today's date
    if date_ is None:
        date_ = datetime.datetime.now()

    # Calculate sunrise and sunset times
    s = sun(location.observer, date=date_)

    # Return the local time of sunrise, sunset, and twilight
    return (
        s['sunrise'],
        s['sunset']
    )

# Update cron job to turn ON or OFF the GPIO pins

latitude = 41.617592
longitude = 0.620015

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(latitude, longitude)
shutdown_time = sunset + timedelta(minutes=100)
print(f'sunset = {sunset}. shutdown_time = {shutdown_time}')
command_shut = "sleep 360 && sudo reboot now"
# Get the user's crontab
cron = CronTab(user=True)
#looking for the job using the comment
exists = False

for job in cron:
    # Find Shutdown
    if job.comment == 'Shutdown':
        job.minute.on(shutdown_time.minute)
        job.hour.on(shutdown_time.hour + 1) # +1 because it's in UTC
        cron.write()
        exists = True

# Create a new GPIOON job if it does not exist
if exists == False:
    job_shut = cron.new(command=command_shut)
    #adding comment on the job
    job_shut.set_comment('Shutdown')
    job_shut.minute.on(shutdown_time.minute)
    job_shut.hour.on(shutdown_time.hour + 3)
    cron.write()
    print(f"New shutdown cron job scheduled for sunrise at {shutdown_time}")
else:
    print(f"Modified shutdown cron job scheduled for sunrise at {shutdown_time + timedelta(hours=1)}")
