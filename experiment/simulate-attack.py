import paramiko
import time
import os

# Configuration - get from environment variables
HOST = os.getenv('HOST')  # EC2 instance IP
PORT = 22
USERNAME = os.getenv('USERNAME')  # SSH username
PASSWORD = os.getenv('PASSWORD')  # SSH password

# Number of attempts
ATTEMPTS = 5

def simulate_brute_force_ssh(host, port, username, password, attempts):
    print(f"Starting brute force SSH attack simulation on {host}")
    for attempt in range(1, attempts + 1):
        try:
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            print(f"Attempt {attempt}: Trying to connect to {host}:{port} as {username}")
            client.connect(host, port=port, username=username, password=password, timeout=10)
        except paramiko.AuthenticationException:
            print("Authentication failed, as expected for a brute force attack simulation.")
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
        finally:
            client.close()
        time.sleep(1)  # Wait a bit between attempts to mimic real-world attack timing

if __name__ == "__main__":
    simulate_brute_force_ssh(HOST, PORT, USERNAME, PASSWORD, ATTEMPTS)
