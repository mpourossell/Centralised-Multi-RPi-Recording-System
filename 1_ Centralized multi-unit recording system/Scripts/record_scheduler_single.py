import config
import pirecorder
from astral.sun import sun
from astral import LocationInfo
from datetime import date, time, timezone, timedelta
import datetime
import socket
import pytz
import config


def get_sunrise_sunset(lat, long, date_=None):
    location = LocationInfo(lat, long)
    tz_lleida = pytz.timezone('Europe/Madrid')

    # If no date is provided, use today's date
    if date_ is None:
        date_ = date.today()

    # Calculate sunrise and sunset times
    s = sun(location.observer, date=date_)

    # Return the local time of sunrise, sunset, and twilight
    return (
        s['sunrise'].astimezone(tz_lleida),
        s['sunset'].astimezone(tz_lleida)
    )


def update_pirecorder(time_now, sunrise, sunset):
    rec_from = time_now + timedelta(minutes=1)
    rec_to = sunset + timedelta(minutes=config.extra_hours * 60)  # Extra minutes to record after sunrise
    rec_duration = int((rec_to - rec_from).total_seconds())
    rec_single = pirecorder.PiRecorder(configfile="single.conf")
    rec_single.settings(imgnr=rec_duration, imgtime=rec_duration)
    rec_timeplan = f"{rec_from.minute} {rec_from.hour} * * *"
    rec_single.schedule(timeplan=rec_timeplan, jobname="single_rec")
    print(f"Recording from {rec_from} to {rec_to} for a duration of {rec_duration} seconds")


# Get today's date
today_date = date.today()

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(config.latitude, config.longitude)
print(f'Sunrise = {sunrise}, Sunset = {sunset}')

##### UPDATE PIRECORDER CONFIGFILES AND RECORDING SCHEDULES BASED ON SUNLIGHT

dt = datetime.datetime.now()
madrid_tz = pytz.timezone(config.timezone)
time_now = madrid_tz.localize(dt)

# Run function
update_pirecorder(time_now, sunrise, sunset)