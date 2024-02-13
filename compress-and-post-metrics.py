import snappy
import requests
import sys

metrics_file_path = sys.argv[1]
remote_write_url = sys.argv[2]
username = sys.argv[3]
password = sys.argv[4]

# Read the Prometheus metrics from the file
with open(metrics_file_path, 'rb') as f:
    metrics_data = f.read()

# Compress the data using Snappy
compressed_data = snappy.compress(metrics_data)

# Post the compressed data to the Prometheus remote_write endpoint
response = requests.post(remote_write_url, data=compressed_data, auth=(username, password),
                         headers={'Content-Encoding': 'snappy', 'Content-Type': 'application/x-protobuf'})

print(f"Response Status Code: {response.status_code}")
print(f"Response Content: {response.content}")
