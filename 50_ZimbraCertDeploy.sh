#!/bin/bash

#Warning: hostname -A appends a space to the end of the returned value
FQDN=$(hostname -A)
FROM="<ZimbreMailServer@$FQDN"
EMAIL="AJREPO@example.com"

cat /opt/zimbra/ssl/message.txt | /opt/zimbra/common/sbin/sendmail -t "$EMAIL"
