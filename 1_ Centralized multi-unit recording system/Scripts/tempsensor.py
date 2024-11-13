# This script reads temperature using the temperature sensor and stores it in a log file.
# It can be run using cron at desired schedules

import logging
import socket
import os

#Set logging parameters
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
file_handler = logging.FileHandler("temperature_" + socket.gethostname() + ".log")
formatter = logging.Formatter("%(asctime)s,%(message)s", "%Y-%m-%d %H:%M:%S")
file_handler.setFormatter(formatter)
stream_handler = logging.StreamHandler()
stream_handler.setFormatter(formatter)
logger.addHandler(file_handler)
logger.addHandler(stream_handler)

def get_sensor_id():
    # Change to the directory where the temperature sensor devices are located
    os.chdir("/sys/bus/w1/devices/")

    # List all devices in the directory
    devices = os.listdir()
    # Check if there are any devices
    if not devices:
        print("No temperature sensor devices found.")
        return None

    # Get the first device as the sensor ID
    sensor_id = devices[0]

    return sensor_id

def get_temp_sens(sensor_id):
    tfile = open(f'/sys/bus/w1/devices/{sensor_id}/w1_slave')
    text = tfile.read()
    tfile.close()
    secondline = text.split("\n")[1]
    temperaturedata = secondline.split(" ")[9]
    temperature = float(temperaturedata[2:])
    temperature = temperature / 1000
    return round(temperature, 2)

sensor_id = get_sensor_id()
message = str(get_temp_sens(sensor_id))
logger.debug(message)
