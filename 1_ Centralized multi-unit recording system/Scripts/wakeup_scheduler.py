#!/usr/bin/python3
# This script updates the wake-up alarm of the PiJuice based on daylight.
# It should be run only in the parent unit.

from pijuice import PiJuice
from astral.sun import sun
from astral import LocationInfo
from datetime import timedelta
import datetime
import config

pijuice = PiJuice(1, 0x14) # Instantiate PiJuice interface object

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
wakeup_time = sunrise - timedelta(hours=2)
print(f'sunrise = {sunrise}. wakeup_time = {wakeup_time}')

pijuice.rtcAlarm.SetAlarm({'second': 0, 'minute': wakeup_time.minute, 'hour': wakeup_time.hour, 'day': 'EVERY_DAY'})