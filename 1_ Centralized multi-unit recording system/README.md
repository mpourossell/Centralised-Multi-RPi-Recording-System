# Design of an automated, centralized, multi-unit monitoring system using Raspberry Pi

Here we provide detailed guidelines to set-up both the hardware and the software of a multiple-unit centralized monitoring system. We provide a shopping list, guidelines to ensamble the electronics and detailed explanations of the software, allowing broad customization. 

## Hardware list
Provide shopping list with all the materials needed.

### Calculations of solar power, storage capacity and budget

Explain that we provide Excel files with the formulas to calculate those things only inserting the number of units and working time. 

## Setting up electronics
### Core unit
Here explain that some electronics have to be "Mounted", like the GPIO pins to the RPi board.
Also, show the picture of how to connect the sensors to the RPi, resistors, LED, ...

### Parent unit extras
Install the PiJuice HAT, connect with the relay board.

### Centralized multiple-unit system with a Relay board
Show connections of the relay board here


## First steps with the Raspberry Pi
### Install Raspbian OS
Link to Jolle's GitHub to set-up Raspbian and so on.
Note that to use Pirecorder, Raspbian Buster should be used instead of Bullseye.

### Software installation for easier connectivity
Bash scripts, python and html (for the web-server indexing)
(Rclone, VNC, clusterssh, ...)
Advanced preps: flask, ngrok, ... for web-server development

### Software for monitoring
Everything is run in python and bash scripts
(Pirecorder, OpenCV, ffmpeg, python-crontab...)

## Software for system replication

Python-based. Explain the config.py script and its functionality to automatically personalize the system.
List all the scripts, provide directory structure needed and briefly explain what each script does, how to customize them and what config-files have to be modified to use them (email, web server, etc).

