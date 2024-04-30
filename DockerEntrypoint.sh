#!/bin/sh

#ssh server
systemctl start ssh

# Start fail2ban
fail2ban-client -x start

# Run x-ui
systemctl start x-ui
