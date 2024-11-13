# This script activates the relay channels using the GPIO pins to power the child units.
# It should be run only in the parent unit, and can be scheduled using cron.

import RPi.GPIO as GPIO

GPIO.setmode(GPIO.BCM)
pinList = [4, 15, 18, 23, 24, 25, 8, 7, 6, 12, 16, 20, 21, 26, 19, 13]

for i in pinList:
    GPIO.setup(i, GPIO.OUT)