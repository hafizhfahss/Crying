#!/bin/sh

# Get the list of pod IPs
POD_IPS=$(kubectl get pods -o wide --no-headers | awk '{print $6}')

# Loop through each IP and ping
for IP in $POD_IPS; do
    echo "Pinging Pod IP: $IP"
    ping -c 4 $IP || echo "Failed to reach $IP"
    echo "-----------------------------------"
done
