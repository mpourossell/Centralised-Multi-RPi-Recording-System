#!/usr/bin/python3
# This script publishes the local web server created with the Flask api to the internet using ngrok.
# Create an account and read doccumentation to create a web domain using ngrok.
# It should be run in the parent unit, also running the flaskapi.py

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
