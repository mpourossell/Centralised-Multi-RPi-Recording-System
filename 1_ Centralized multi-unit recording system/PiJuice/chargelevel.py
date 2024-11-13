#!/usr/bin/python3

from pijuice import PiJuice # Import pijuice module
import logging
import socket

logger = logging.getLogger('charge_level')
hdlr = logging.FileHandler('/home/pi/chargelevel_' + socket.gethostname() + '.log')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr)
logger.setLevel(logging.INFO)

pijuice = PiJuice(1, 0x14) # Instantiate PiJuice interface object
logger.info(str(pijuice.status.GetChargeLevel()))