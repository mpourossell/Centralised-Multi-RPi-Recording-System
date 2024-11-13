# This script cuts the current of the GPIO pins listed. It's used to cut the current to the relay channels
# and power off the child units. It should be run only in the parent unit, and can be run using cron.

import RPi.GPIO as GPIO

GPIO.setmode(GPIO.BCM)
pinList = [4, 15, 18, 23, 24, 25, 8, 7, 6, 12, 16, 20, 21, 26, 19, 13]

for i in pinList:
    GPIO.setup(i, GPIO.OUT)
GPIO.cleanup()