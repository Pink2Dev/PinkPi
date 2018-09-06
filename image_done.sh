#!/bin/bash
set -e

HOME="/home/pi"

# Clear history
history -c
history -w

# Clear log files
find "/var/log/" -type f -exec cp /dev/null {} \;

# Delete any SSH configuration
rm -fR "$HOME/.ssh"

# Delete any wallet configuration
rm "$HOME/.pink2/pinkconf.txt"

# Delete any wallet file
rm "$HOME/.pink2/wallet.dat"

# Reset to static network
"$HOME/scripts/network_reset.sh"

# Arm first-boot setup
echo "@reboot pi cd \"$HOME\" && ./once.sh >> once.log 2>&1" >> "$HOME/crontab/pinkpi"

# Self-destruct
rm "$0"

# Do not get a$$ prints on someone's new door
shutdown -h now
