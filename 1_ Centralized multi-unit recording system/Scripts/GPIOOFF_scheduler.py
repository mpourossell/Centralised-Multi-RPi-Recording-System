# This script updates the relay activation schedules according to daylight


from astral.sun import sun
from astral import LocationInfo
from datetime import timedelta
import datetime
from crontab import CronTab
import config

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

latitude = config.latitude
longitude = config.longitude

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(latitude, longitude)

# Give 2 min extra to the RPi to be on before its own shutdown
extra_sunset = sunset + timedelta(hours=config.extra_hours) + timedelta(minutes=(config.extra_minutes-2))

# Calculate the cron expression for sunrise
cron_off = f"{extra_sunset.minute} {extra_sunset.hour + 1} * * *" # +1 as it is in UTC

# Define the command you want to run
command_off = "/usr/bin/python3 /home/pi/Scripts/GPIOOFF.py"

# Get the user's crontab
cron = CronTab(user=True)

#looking for the job using the comment
exists_on = False
exists_off = False
for job in cron:
    # Find GPIOOFF
    if job.comment == 'GPIOOFF':
        job.minute.on(extra_sunset.minute)
        job.hour.on(extra_sunset.hour + 1)
        cron.write()
        exists_off = True
        print(f"GPIOOFF cron job scheduled for sunrise at {extra_sunset + timedelta(hours=1)}")

# Create a new GPIOOFF job if it does not exist
if exists_off == False:
    job_off = cron.new(command=command_off)
    #adding comment on the job
    job_off.set_comment('GPIOOFF')
    job_off.minute.on(extra_sunset.minute)
    job_off.hour.on(extra_sunset.hour)
    cron.write()
    print(f"GPIOOFF cron job scheduled for sunrise at {extra_sunset + timedelta(hours=1)}")
else:
    pass
