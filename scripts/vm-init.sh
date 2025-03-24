#!/bin/bash

# Create a log file for troubleshooting
exec > >(tee -a /var/log/user-data.log) 2>&1
echo "Starting custom script execution at $(date)"

# Install required packages
echo "Updating package lists..."
sudo apt-get update
echo "Installing Nginx, JQ, and curl..."
sudo apt-get install -y nginx jq curl

# Make sure nginx is enabled and started
echo "Enabling and starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Function to get metadata with retries
get_metadata() {
  local max_attempts=10
  local attempt=1
  local result=""
  
  echo "Attempting to retrieve instance metadata..."
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt of $max_attempts..."
    
    # Try to get the compute information from metadata service
    result=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$result" ] && [ "$result" != "null" ]; then
      echo "Successfully retrieved metadata"
      echo "$result" > /tmp/metadata.json
      return 0
    fi
    
    echo "Metadata retrieval failed or returned empty, retrying in 5 seconds..."
    sleep 5
    ((attempt++))
  done
  
  echo "Failed to retrieve metadata after $max_attempts attempts"
  return 1
}

# Get metadata and extract relevant information
get_metadata

# Extract VM information from metadata
if [ -f /tmp/metadata.json ]; then
  vmId=$(jq -r '.compute.vmId' /tmp/metadata.json)
  vmName=$(jq -r '.compute.name' /tmp/metadata.json)
  vmSize=$(jq -r '.compute.vmSize' /tmp/metadata.json)
  zone=$(jq -r '.compute.zone' /tmp/metadata.json)
else
  echo "Metadata file not found, using fallback values"
  vmId="metadata-unavailable"
  vmName="unknown"
  vmSize="unknown"
  zone="unknown"
fi

# Create a more informative HTML page
echo "Creating custom index.html with VM information..."
cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Azure Web App Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f0f0f0;
        }
        .container {
            background-color: white;
            border-radius: 5px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #0078d4;
        }
        .vm-info {
            margin-top: 20px;
            padding: 15px;
            background-color: #e6f3ff;
            border-radius: 5px;
        }
        .timestamp {
            margin-top: 20px;
            font-size: 0.8em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to my Azure Web App!</h1>
        <p>This page is being served by Nginx on a VM in a Scale Set</p>
        
        <div class="vm-info">
            <h2>Virtual Machine Information:</h2>
            <p><strong>VM ID:</strong> ${vmId}</p>
            <p><strong>VM Name:</strong> ${vmName}</p>
            <p><strong>VM Size:</strong> ${vmSize}</p>
            <p><strong>Zone:</strong> ${zone}</p>
        </div>
        
        <div class="timestamp">
            <p>Page generated at: $(date)</p>
            <p>Server address: $(hostname -I | awk '{print $1}')</p>
        </div>
    </div>
</body>
</html>
HTML

# Test if Nginx is serving the page correctly
echo "Testing Nginx configuration..."
curl -s http://localhost > /dev/null
if [ $? -eq 0 ]; then
  echo "Nginx is serving the page correctly"
else
  echo "Error: Nginx is not serving the page correctly"
  echo "Nginx status:"
  sudo systemctl status nginx
fi

echo "Custom script execution completed at $(date)"