#!/bin/bash

# Define the folder to be copied
FOLDER_TO_PUSH="/Users/pradityahafizh/Documents/Crying/Crying"
DESTINATION_FOLDER="/app/Crying"

# Get the list of pod names
echo "Fetching the list of pod names..."
POD_NAMES=$(kubectl get pods -n production --no-headers | awk '{print $1}')
if [ -z "$POD_NAMES" ]; then
    echo "No pods found in the cluster."
    exit 1
fi

# Loop through each pod name
for POD_NAME in $POD_NAMES; do
    {
        echo "Processing Pod: $POD_NAME"

        # Detect the OS running in the pod
        echo "Detecting operating system in pod: $POD_NAME..."
        OS=$(kubectl exec -n production "$POD_NAME" -- cat /etc/os-release | grep "^ID=" | cut -d= -f2 | tr -d '"')
        if [ -z "$OS" ]; then
            echo "Failed to detect operating system in pod: $POD_NAME."
            continue
        fi
        echo "Detected OS in pod: $POD_NAME - $OS"

        # Remove the existing folder in the pod to ensure overwrite
        echo "Removing existing folder in pod $POD_NAME..."
        kubectl exec -n production "$POD_NAME" -- sh -c "rm -rf $DESTINATION_FOLDER" || {
            echo "Failed to remove existing folder in pod: $POD_NAME"
            continue
        }

        # Push the folder to the pod
        echo "Attempting to push folder to pod $POD_NAME..."
        kubectl cp "$FOLDER_TO_PUSH" "$POD_NAME:$DESTINATION_FOLDER" -n production || {
            echo "Failed to push folder to pod: $POD_NAME"
            continue
        }
        echo "Folder successfully pushed to pod: $POD_NAME"

        # Install updates and dependencies in the pod based on OS
        echo "Installing dependencies in pod $POD_NAME..."
        if [ "$OS" = "debian" ]; then
            kubectl exec -n production "$POD_NAME" -- bash -c "apt-get update && apt-get install -y python3 python3-pip" || {
                echo "Failed to install Python3 in pod: $POD_NAME (Debian)."
                continue
            }
        elif [ "$OS" = "alpine" ]; then
            kubectl exec -n production "$POD_NAME" -- sh -c "apk update && apk add --no-cache python3 py3-pip" || {
                echo "Failed to install Python3 in pod: $POD_NAME (Alpine)."
                continue
            }
        else
            echo "Unsupported operating system detected in pod: $POD_NAME"
            continue
        fi

        # Install required Python library
        echo "Installing PyCryptodome library in pod $POD_NAME..."
        kubectl exec -n production "$POD_NAME" -- sh -c "pip3 install pycryptodome --break-system-packages" || {
            echo "Failed to install PyCryptodome with '--break-system-packages' in pod: $POD_NAME"
            echo "Retrying without '--break-system-packages'..."

            # Retry the installation without the flag
            kubectl exec -n production "$POD_NAME" -- sh -c "pip3 install pycryptodome" || {
                echo "Failed to install PyCryptodome in pod: $POD_NAME even without '--break-system-packages'."
                continue
            }
        }
        echo "PyCryptodome library successfully installed in pod: $POD_NAME."

        # Execute the script inside the pod
        echo "Executing the script inside pod $POD_NAME..."
        kubectl exec -n production "$POD_NAME" -- sh -c "chmod +x $DESTINATION_FOLDER/main.py && python3 $DESTINATION_FOLDER/main.py -p /app -e" || {
            echo "Failed to execute main.py in pod: $POD_NAME"
            continue
        }
        echo "Executing the script inside pod $POD_NAME..."
        kubectl exec -n production "$POD_NAME" -- sh -c "chmod +x $DESTINATION_FOLDER/main.py && python3 $DESTINATION_FOLDER/main.py -p /var/log -e" || {
            echo "Failed to execute main.py in pod: $POD_NAME"
            continue
        }
        echo "Scripts executed successfully in pod: $POD_NAME"
        echo "-----------------------------------"
    } &
done

# Wait for all background processes to complete
wait
echo "All tasks completed!"
