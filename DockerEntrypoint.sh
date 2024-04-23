#!/bin/sh

#ssh server
sleep 5;touch /run/openrc/softlevel
sleep 1
rc-status
sleep 1
rc-service sshd start

# Start fail2ban
fail2ban-client -x start

# Run x-ui
exec /app/x-ui
