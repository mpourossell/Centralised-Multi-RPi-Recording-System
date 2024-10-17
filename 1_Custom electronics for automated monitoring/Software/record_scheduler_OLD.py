import pirecorder
from astral.sun import sun
from astral import LocationInfo
from datetime import date, time, timezone, timedelta
import datetime

def get_sunrise_sunset(lat, long, date_=None):
    location = LocationInfo(lat, long)

    # If no date is provided, use today's date
    if date_ is None:
        date_ = date.today()

    # Calculate sunrise and sunset times
    s = sun(location.observer, date=date_)

    # Return the local time of sunrise, sunset, and twilight
    return (
        s['sunrise'],
        s['sunset']
    )

# Update pirecorder configfile with recording schedules
def update_pirecorder(wakeup_datetime, sunrise, sunset, sleep_datetime, extra_min):
    # Set recording time to morning recording
    rec_morning_duration = int(((sunrise - timedelta(minutes=2)) - wakeup_datetime + timedelta(minutes=extra_min)).total_seconds())
    print(f"rec_morning will record for {rec_morning_duration} seconds.")
    rec_morning = pirecorder.PiRecorder(configfile = "morning.conf")
    rec_morning.settings(imgnr = rec_morning_duration, imgtime = rec_morning_duration)

    # Set recording time to daylight recording
    rec_day_duration = int(((sunset - timedelta(minutes=2)) - sunrise - 2 * timedelta(minutes=extra_min)).total_seconds())
    print(f"rec_day will record for {rec_day_duration} seconds.")
    rec_day = pirecorder.PiRecorder(configfile = "day.conf")
    rec_day.settings(imgnr = rec_day_duration, imgtime = rec_day_duration)

    # Set recording time to evening recording
    rec_evening_duration = int((sleep_datetime - sunset + timedelta(minutes=extra_min)).total_seconds())
    print(f"rec_evening will record for {rec_evening_duration} seconds.")
    rec_evening = pirecorder.PiRecorder(configfile = "evening.conf")
    rec_evening.settings(imgnr = rec_evening_duration, imgtime = rec_evening_duration)

    # Set schedules for the recording according to daylight
    sunrise = sunrise + timedelta(minutes=extra_min)
    sunset = sunset - timedelta(minutes=extra_min)
    rec_morning_timeplan = f"{wakeup_datetime.minute} {wakeup_datetime.hour + 1} * * *" # +1 hour as it was in UTC time
    rec_morning.schedule(timeplan = rec_morning_timeplan, jobname = "morning")
    rec_day_timeplan = f"{sunrise.minute} {sunrise.hour + 1} * * *" # +1 hour as it was in UTC time
    rec_day.schedule(timeplan = rec_day_timeplan, jobname = "day")
    rec_evening_timeplan = f"{sunset.minute} {sunset.hour + 1} * * *" # +1 hour as it was in UTC time
    rec_evening.schedule(timeplan = rec_evening_timeplan, jobname = "evening")


##### GET SUNRISE AND SUNSET TIMES IN LLEIDA FOR TODAY
# Get today's date and location of Lleida
today_date = date.today()
latitude = 41.617592
longitude = 0.620015

# Get sunrise and suset times
sunrise, sunset = get_sunrise_sunset(latitude, longitude)


##### UPDATE PIRECORDER CONFIGFILES AND RECORDING SCHEDULES
# Update pirecorder configfiles to record with the schedules based on sunset and sunrise times
sleep_datetime = sunset + timedelta(minutes=90)
# Check time at the moment of script run (at boot of the Raspberry Pi)
time_now = datetime.datetime.now().replace(tzinfo=timezone.utc)
time_now = sunrise - timedelta(minutes=90)
# If RPi powers up before the scheduled wake-up from master:
# Edit morning recording in case RPi woke up in mid morning
if (time_now - timedelta(hours=1)) < sunrise:
    wakeup_datetime = time_now + timedelta(minutes=1) # Set to current time, give 1 minures or margin to start the recording
else:
    extra_sunrise = sunrise - timedelta(minutes=90) # 90 because Master RPi is programmed to open relay board 95 minutes before. So give 5mi$
    extra_sunset = sunset + timedelta(minutes=90)
    wakeup_datetime = extra_sunrise
# Edit day recording in case RPi woke up in mid day:
if sunrise < (time_now - timedelta(hours=1)) < sunset:
    sunrise = time_now - timedelta(hours=1) + timedelta(minutes=1) # Set to current time, give 2 minures or margin to start the recording
else:
    sunrise = sunrise
# Edit day recording in case RPi woke up in mid evening:
if sunset < (time_now - timedelta(hours=1)):
    sunset = time_now + timedelta(minutes=1) # Set to current time, give 1 minures or margin to start the recording
else:
    pass

extra_min = 60
update_pirecorder(wakeup_datetime, sunrise, sunset, sleep_datetime, extra_min)
