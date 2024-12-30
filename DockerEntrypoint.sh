#!/bin/sh

#ssh server
/etc/init.d/ssh start

# Start fail2ban
systemctl start fail2ban

# Run x-ui
#systemctl start x-ui
exec /usr/local/x-ui/x-ui

#Keep Container Running
#tail -f /dev/null
