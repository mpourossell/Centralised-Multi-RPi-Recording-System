# This script updates the recording schedules according to daylight (if multiple types of recordings are needed acrosst the day).
# For example, morning and evening might have lower light conditions. Then, for these periods higher
# exposure recording might be preferred than the automatic exposure used to record during the day.

# If some units are having higher exposure during the evening (because of the direction of the camera),
# they can be set to perform different than the others.

import config
import pirecorder
from astral.sun import sun
from astral import LocationInfo
from datetime import date, time, timezone, timedelta
import datetime
import socket
import pytz


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


# Update pirecorder configfile with recording schedules
def update_pirecorder(time_now, sunrise, sunset, extra_min, evening_delay, sunny_evening_list):
    # Set recording time to morning recording
    # Edit morning recording in case RPi woke up after scheduled wakeup time:
    wakeup_datetime = sunrise - timedelta(minutes=90)
    if (wakeup_datetime < time_now < (sunrise - timedelta(minutes=extra_min))):
        wakeup_datetime = time_now  # Set wakeup time to current time, give 1 minures or margin to start the recording
        print(f'Woke up later than expected: wakeup_datetime = time_now')
    else:
        print(f'Wake up time as expected: Wakeup_datetime = sunrise - 90min')

    morning_from = wakeup_datetime + timedelta(minutes=2)
    morning_to = sunrise + timedelta(minutes=extra_min)  # Extra minutes to record after sunrise
    rec_morning_duration = int((morning_to - morning_from).total_seconds())
    rec_morning = pirecorder.PiRecorder(configfile="morning.conf")
    rec_morning.settings(imgnr=rec_morning_duration, imgtime=rec_morning_duration)

    # Set recording time to daylight recording
    # Edit day recording in case RPi woke up in mid day:
    print(f'sunrise {sunrise}')
    print(f'time_now {time_now}')
    print(f'sunset {sunset}')
    if sunrise < time_now < sunset:
        day_from = time_now + timedelta(
            minutes=1)  # Set to current time, give 2 minures or margin to start the recording
        print(f'Sunrise = {sunrise}. Day_from = {day_from}. Time_now = {time_now}')
        print(f'Woke up in mid-day: Sunrise = time_now')
    else:
        day_from = morning_to + timedelta(minutes=1)  # give 1 minute between recordin

    for Hostname in sunny_evening_list:
        if socket.gethostname() == Hostname:
            day_to = sunset - timedelta(minutes=extra_min) + timedelta(minutes=evening_delay)
        else:
            day_to = sunset - timedelta(minutes=extra_min)
    rec_day_duration = int((day_to - day_from).total_seconds())
    rec_day = pirecorder.PiRecorder(configfile="day.conf")
    rec_day.settings(imgnr=rec_day_duration, imgtime=rec_day_duration)

    # Set recording time to evening recording
    # Edit evening recording in case RPi woke up in mid evening:
    if sunset < (time_now):
        evening_from = time_now + timedelta(
            minutes=1)  # Set to current time, give 1 minures or margin to start the recording
    else:
        evening_from = day_to + timedelta(minutes=3)  # give 2 minutes between recordings

    evening_to = sunset + timedelta(minutes=90)

    rec_evening_duration = int((evening_to - evening_from).total_seconds())
    rec_evening = pirecorder.PiRecorder(configfile="evening.conf")
    rec_evening.settings(imgnr=rec_evening_duration, imgtime=rec_evening_duration)

    # Set schedules for the recording according to daylight
    rec_morning_timeplan = f"{morning_from.minute} {morning_from.hour} * * *"
    rec_morning.schedule(timeplan=rec_morning_timeplan, jobname="morning")
    rec_day_timeplan = f"{day_from.minute} {day_from.hour} * * *"
    rec_day.schedule(timeplan=rec_day_timeplan, jobname="day")
    rec_evening_timeplan = f"{evening_from.minute} {evening_from.hour} * * *"
    rec_evening.schedule(timeplan=rec_evening_timeplan, jobname="evening")

    print(
        f"rec_morning will record from {morning_from.strftime('%X')} to {morning_to.strftime('%X')} for {rec_morning_duration} seconds.")
    print(
        f"rec_day will record from {day_from.strftime('%X')} to {day_to.strftime('%X')} for {rec_day_duration} seconds.")
    print(
        f"rec_evening will record from {evening_from.strftime('%X')} to {evening_to.strftime('%X')} for {rec_evening_duration} seconds.")


##### GET SUNRISE AND SUNSET TIMES IN LLEIDA FOR TODAY
# Get today's date and location of Lleida
today_date = date.today()
latitude = config.latitude
longitude = config.longitude

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(latitude, longitude)
print(f'Sunrise = {sunrise}, Sunset = {sunset}')

##### UPDATE PIRECORDER CONFIGFILES AND RECORDING SCHEDULES BASED ON SUNLIGHT

dt = datetime.datetime.now()
madrid_tz = pytz.timezone('Europe/Madrid')
time_now = madrid_tz.localize(dt)
print(f'Time_now = {time_now}')
extra_min = 30
evening_delay = 30
sunny_evening_list = ["jackdaw04", "jackdaw06", "jackdaw08", "jackdaw10",
                      "jackdaw11"]  # List of nest boxes with direct sunlight in the box at evening

# Run function
update_pirecorder(time_now, sunrise, sunset, extra_min, evening_delay, sunny_evening_list)