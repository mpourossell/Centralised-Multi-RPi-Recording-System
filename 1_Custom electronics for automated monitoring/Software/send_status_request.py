import requests
import subprocess
import psutil
import socket
import time
import os
import datetime
import config

def get_cpu_temperature():
    res = subprocess.check_output(["vcgencmd", "measure_temp"]).decode("utf-8")
    cpu_usage = psutil.cpu_percent()
    cpu_temperature = float(res.replace("temp=", "").replace("'C\n", ""))
#    cpu_info = f"{res_str}ºC, {cpu_usage}"
    return cpu_temperature, cpu_usage

def get_storage_space():
    disk = psutil.disk_usage('/')
    percentage_use = disk.percent
    available_space = round(disk.free/1024.0/1024.0/1024.0,1)
    total_space = round(disk.total/1024.0/1024.0/1024.0,1)
#    disk_info = f'{str(free)}/{str(total)}GB ({str(disk.percent)}%)'
    return available_space, total_space, percentage_use

def is_camera_used():
    camera_status = subprocess.getoutput("ps aux | grep 'record' | grep -wv grep")
    if camera_status:
        camera = f'Recording'
    else:
        camera = f'NOT recording'
    return camera

def gdrive_mount():
    if os.path.exists(config.targ_dir):
        gdrive_status = "Connected"
    else:
        gdrive_status = "Disconnected"
    return gdrive_status

def get_temperature(file_path):
    with open(file_path, "r") as file:
        lines = file.readlines()
        return lines[-1] if lines else "No log entries yet."

def get_pirecorder_log():
    directory_path = '/home/pi/pirecorder/recordings'
    directories = [d for d in os.listdir(directory_path) if os.path.isdir(os.path.join(directory_path, d))]

    # Sort directories by creation time
    directories.sort(key=lambda x: os.path.getctime(os.path.join(directory_path, x)))

    # Get the last (most recently created) directory
    last_directory = directories[-1]
    full_path_to_last_directory = os.path.join(directory_path, last_directory)

    # Get a list of all files in the last directory
    files_in_last_directory = os.listdir(full_path_to_last_directory)

    # Sort files by creation time
    files_in_last_directory.sort(key=lambda x: os.path.getctime(os.path.join(full_path_to_last_directory, x)))

    # Get the last (most recently created) file in the last directory
    last_file = files_in_last_directory[-1]

    return last_file

def collect_status(temperature_logfile):
    # Implement logic to collect status information (CPU temperature, storage space, etc.)
    status_data = {
        'hostname': socket.gethostname(),
        'datetime': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        'cpu_temperature': get_cpu_temperature()[0],
        'cpu_usage': get_cpu_temperature()[1],
        'nest_temperature': get_temperature(temperature_logfile),
        'available_space': get_storage_space()[0],
        'total_space': get_storage_space()[1],
        'percentage_use': get_storage_space()[2],
        'gdrive_mount': gdrive_mount(),
        'camera_status': is_camera_used(),
        'last_recording': get_pirecorder_log()
        # Add more fields as needed
    }
    return status_data

def send_info():
    # Specify the path to the temperature log file
    temperature_logfile = f'/home/pi/temperature_{socket.gethostname()}.log'
    # Collect status information
    status_data = collect_status(temperature_logfile)

    # Send data to the master Raspberry Pi
    try:
        print(f"Sending data: {status_data}")
        response = requests.post(f'http://{config.parent_hostname}.local:8080/update_data', json=status_data)
        print(f"Response received: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Error sending data to {config.parent_hostname}: {e}")

if __name__ == "__main__":
    for _ in range(29):
        send_info()

        # Wait for 5 seconds before sending the next update
        time.sleep(2)