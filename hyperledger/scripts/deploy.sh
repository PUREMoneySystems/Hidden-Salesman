#!/bin/bash

ORIGINAL_PATH=$(pwd)
CURRENT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NETWORK_NAME="black-poc"
NETWORK_ADMIN="admin"
NETWORK_ADMIN_SECRET="adminpw"
NETWORK_ADMIN_CARD="$NETWORK_ADMIN@$NETWORK_NAME"
NETWORK_ADMIN_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/networkadmin.card"
INSTALLER_CARD="PeerAdmin@hlfv1"


# Make sure that Fabric is running and the PeerAdmin exists
SYSTEM_IS_READY=$(composer card list --name PeerAdmin@hlfv1 | grep "Command succeeded" | wc -l)
if [ $SYSTEM_IS_READY -eq "0" ]; then
    echo "The PeerAdmin card could not be located in Fabric"
    exit 1
fi

# Create the archive with the current contents
composer archive create -t dir -n ./black-poc

# Get the archive name from the most recently created BNA file
NEW_ARCHIVE="$ORIGINAL_PATH$(ls -t ./*.bna | head -1 | cut -c 2-)"

# Ping the Network to see if it is running
NETWORK_EXISTS=$(composer network ping --card $NETWORK_ADMIN_CARD | grep "Command succeeded" | wc -l)
if [ $NETWORK_EXISTS -eq "0" ]; then
    echo "The $NETWORK_NAME is not available.  Installing this network for the first time..."

    # Install the Composer Runtime with the Installer Card
    composer runtime install --card $INSTALLER_CARD --businessNetworkName $NETWORK_NAME

    # Deploy the archive for the first time and create the Network Admin
    composer network start --card $INSTALLER_CARD --networkAdmin $NETWORK_ADMIN --networkAdminEnrollSecret $NETWORK_ADMIN_SECRET --archiveFile $NEW_ARCHIVE --file $NETWORK_ADMIN_CARD_PATH

    # Import the new Network Admin card
    composer card import --file $NETWORK_ADMIN_CARD_PATH
else
    # Update the existing Network using the Network Admin card
    composer network update --card $NETWORK_ADMIN_CARD --archiveFile $NEW_ARCHIVE
fi

