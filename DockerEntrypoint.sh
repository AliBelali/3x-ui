#!/bin/sh

#ssh server
/etc/init.d/ssh start

# Start fail2ban
fail2ban-client -x start 

# Run x-ui
exec /usr/local/x-ui/x-ui
