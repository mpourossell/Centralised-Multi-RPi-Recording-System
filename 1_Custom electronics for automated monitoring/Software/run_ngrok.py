#!/usr/bin/python3

import subprocess
import datetime
import config

def run_ngrok():
    try:
        ngrok_command = f"/usr/local/bin/ngrok http --domain={config.web_server_domain} 8080"
        subprocess.run(ngrok_command, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"{datetime.datetime.now()} Error running ngrok: {e}")

if __name__ == "__main__":
    run_ngrok()
