#!/bin/bash
# Author: AJRepo
# License: GPLv3

#Script to test zimbra and certbot environment to see if both are
#setup ok.

#Check name used
ZIMBRA_HOSTNAME=$(zmhostname)
echo "FQDN reported as $ZIMBRA_HOSTNAME"

#Check ports used (does it require port 80 for certbot?)
ZIMBRA_SERVER_PORT=$(zmprov getServer $ZIMBRA_HOSTNAME zimbraMailProxyPort)

#get all hostnames (gad)
ZIMBRA_ALL_DOMAINS=$(zmprov getAllDomains)

echo "Checking all domains to see if compatible with zimbra certbot renewal" 

#get domain (gd)
for ZIMBRA_PUBLIC in $ZIMBRA_ALL_DOMAINS; do
	THIS_PUBLIC_DOMAIN=$(zmprov getDomain $ZIMBRA_PUBLIC zimbraPublicServiceHostname | grep zimbraPublicServiceHostname | awk '{print $2}')
	if [[ $THIS_PUBLIC_DOMAIN == $ZIMBRA_HOSTNAME ]]; then
		echo "$ZIMBRA_PUBLIC is OK"
	else
		echo "$ZIMBRA_PUBLIC has $THIS_PUBLIC_DOMAIN domain instead of $ZIMBRA_HOSTNAME"
	fi
done
