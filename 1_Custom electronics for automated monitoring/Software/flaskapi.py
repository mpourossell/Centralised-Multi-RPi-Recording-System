from flask import Flask, render_template, request
import sqlite3
from datetime import datetime
from flask_basicauth import BasicAuth
import config

app = Flask(__name__)
basic_auth = BasicAuth(app)

app.config['BASIC_AUTH_USERNAME'] = config.web_login_username
app.config['BASIC_AUTH_PASSWORD'] = config.web_login_password

# Function to insert data into the database
def insert_data(data):
    connection = sqlite3.connect('pi_data.db')
    cursor = connection.cursor()
    cursor.execute('''
        INSERT INTO pi_status (hostname, datetime, cpu_temperature, cpu_usage, nest_temperature, available_space, total_space, percentage_use, camera_status, last_recording, gdrive_mount)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (data['hostname'], data['datetime'], data['cpu_temperature'], data['cpu_usage'], data['nest_temperature'], data['available_space'], data['total_space'], data['percentage_use'], data['camera_status'], data['last_recording'], data['gdrive_mount']))
    connection.commit()
    connection.close()

def get_latest_data_for_unique_hosts():
    connection = sqlite3.connect('pi_data.db')
    cursor = connection.cursor()
    cursor.execute('''
        SELECT * FROM pi_status
        WHERE (hostname, datetime) IN (
            SELECT hostname, MAX(datetime)
            FROM pi_status
            GROUP BY hostname
        )
        ORDER BY hostname
    ''')
    data = cursor.fetchall()
    connection.close()
    return data

@app.route('/')
@basic_auth.required

def index():
    # Get the latest data from the database for unique hosts
    latest_data_for_unique_hosts = get_latest_data_for_unique_hosts()

    # Create a dictionary to store the latest data for each hostname
    latest_data_dict = {row[1]: row for row in latest_data_for_unique_hosts}

    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Render HTML template with gathered information
    return render_template('index.html', latest_data_dict=latest_data_dict, current_time=current_time)

@app.route('/update_data', methods=['POST'])
def update_data():
    # Receive data from a child Raspberry Pi
    data = request.json
    insert_data(data)
    return 'Data received successfully'

if __name__ == '__main__':
    # Create the database table if not exists
    connection = sqlite3.connect('pi_data.db')
    cursor = connection.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pi_status (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hostname TEXT,
            datetime TEXT,
            cpu_temperature TEXT,
            cpu_usage TEXT,
            nest_temperature TEXT,
            available_space TEXT,
            total_space TEXT,
            percentage_use TEXT,
            gdrive_mount TEXT,
            camera_status TEXT,
            last_recording TEXT
            -- Add more fields as needed
        )
    ''')
    connection.close()

    # Run the Flask application
    app.run(host='0.0.0.0', port=8080, debug=True)