#!/bin/bash

#Warning: hostname -A adds a space to the end of returned value(s)
FQDN=$(hostname -A | sed -e /\ /s///g)
FROM="<ZimbreMailServer@$FQDN"
EMAIL="AJREPO@example.com"
Z_BASE_DIR="/opt/zimbra"
X3_FILE=$Z_BASE_DIR/ssl/letsencrypt/lets-encrypt-x3-cross-signed.pem.txt

MESSAGE_FILE="/tmp/message.txt"

#TODO: make sleep till reboot time a geopts option
##Seconds until the next Mail Server Restart time (3am)
#if [[ $(date +%H) -gt 3 ]]; then
#  RESTART_TIME=$(date +%s -d "3am tomorrow")
#else
#  RESTART_TIME=$(date +%s -d "3am")
#fi
#
#NOW=$(date +%s)
#SECONDS_TIL_START=$(echo "$RESTART_TIME - $NOW" | bc)

echo "Sleeping for $SECONDS_TIL_START seconds"
sleep "$SECONDS_TIL_START"

echo "Subject: Letsencrypt Renewal of Zimbra Cert done
From: <$FROM>

Zimbra Certificate Renewal done
This message generated by /etc/letsencrypt/renewal-hooks/deploy/ajonotify.sh" > $MESSAGE_FILE

TODAY=$(date +%Y%m%d)

#Make Backup Directory
mkdir -p "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY"
if [[ $(  mkdir -p "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY") -ne 0 ]]; then
  echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  Unable to make backup directory" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
  exit 1
fi
chown zimbra:zimbra "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY"


#Backup Old Cert
if [[ $(cp $Z_BASE_DIR/ssl/letsencrypt/*.pem $Z_BASE_DIR/ssl/letsencrypt/bak."$TODAY"/) -ne 0 ]]; then
  echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  Unable to backup old Certiricate, stopping" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
  exit 1
fi

#Copy New Cert
if [[ $(cp /etc/letsencrypt/live/"$FQDN"/* $Z_BASE_DIR/ssl/letsencrypt/) -ne 0 ]]; then
  echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  Unable to copy new Certiricate to $Z_BASE_DIR/ssl/letsencrypt, stopping" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
  exit 1
fi

#Chaining Cert
#https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt
#https://letsencrypt.org/certs/letsencryptauthorityx3.pem.txt
#https://letsencrypt.org/certs/trustid-x3-root.pem.txt

X3CERTURI="https://letsencrypt.org/certs/trustid-x3-root.pem.txt"
#X3 Cert chaining
if [[ $(curl -o /tmp/lets-encrypt-x3-cross-signed.pem.txt $X3CERTURI) -ne 0 ]]; then
  echo "Subject: WARNING: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  Unable to download X3 Cross Signed Cert" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
fi

if [[ -f "$X3_FILE" ]]; then
  #compare to see if X3 Cert changed
  if [[ $(diff /tmp/lets-encrypt-x3-cross-signed.pem.txt $X3_FILE) -ne 0 ]]; then
    echo "Subject: WARNING: X3 cert download differs from previous X3 cert
From: <$FROM>

    The downloaded X3 Cross Signed Cert differs from what was saved previously.
    This might be ok if this is the first time you've run this program or if it actually changed
    but flagging anyway."
  fi
else
  cp /tmp/lets-encrypt-x3-cross-signed.pem.txt $Z_BASE_DIR/ssl/letsencrypt/
  chown zimbra:zimbra $X3_FILE
fi

if [[ -f "$X3_FILE" && -f "$Z_BASE_DIR/ssl/letsencrypt/chain.pem" ]]; then
  cat $X3_FILE >> $Z_BASE_DIR/ssl/letsencrypt/chain.pem
  chown zimbra:zimbra $Z_BASE_DIR/ssl/letsencrypt/*
else
  echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  $X3_FILE or chain.pem file missing. stopping" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
  exit 1
fi

cd $Z_BASE_DIR/ssl/letsencrypt/ || exit 1
if [[ $(sudo -u zimbra $Z_BASE_DIR/bin/zmcertmgr verifycrt comm $Z_BASE_DIR/ssl/letsencrypt/privkey.pem $Z_BASE_DIR/ssl/letsencrypt/cert.pem $Z_BASE_DIR/ssl/letsencrypt/chain.pem) -ne 0 ]]; then
  #echo "Certcheck failed with zimbra"
  echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

  Check of certificate failed. stopping" > $MESSAGE_FILE
  $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
  exit 1
fi


#Deply and Restart
sudo -u zimbra -g zimbra -i bash << EOF
  $Z_BASE_DIR/bin/zmproxyctl stop
EOF
if [[ $? -ne 0 ]]; then
 echo "'zmproxyctl stop' command failed"
 exit 1
fi
sudo -u zimbra -g zimbra -i bash << EOF
  $Z_BASE_DIR/bin/zmmailboxdctl stop
EOF
if [[ $? -ne 0 ]]; then
 echo "'zmmailboxctl stop' command failed"
 exit 1
fi

#backup zimbra certs
cp -r $Z_BASE_DIR/ssl/zimbra $Z_BASE_DIR/ssl/zimbra."$TODAY"
chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra."$TODAY"

#Is $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key a softlink to privkey.pem?
if [[ -h $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key ]]; then
  #check that link goes to correct spot
  COMM_KEY=$(readlink -f $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key)
  if [[ $COMM_KEY != "$Z_BASE_DIR/ssl/letsencrypt/privkey.pem" ]]; then
    echo "ERROR: link goes to wrong place, Exiting"
    exit 1
  fi
else
  if [[ $(cp $Z_BASE_DIR/ssl/letsencrypt/privkey.pem $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key) -ne 0 ]]; then
    echo "Subject: ERROR: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

    Copy of privkey.pem to commercial.key failed. stopping" > $MESSAGE_FILE
    $Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
    exit 1
  fi
  chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key
fi

#Deploy Certificate
sudo -u zimbra -g zimbra -i bash << EOF
  $Z_BASE_DIR/bin/zmcertmgr deploycrt comm $Z_BASE_DIR/ssl/letsencrypt/cert.pem $Z_BASE_DIR/ssl/letsencrypt/chain.pem
EOF
if [[ $? -ne 0 ]]; then
 echo "'certmgr deplycrt comm' command failed"
 exit 1
fi

#have to wait 60 seconds or so for zimlet to restart so best to do this at night
sudo -u zimbra -g zimbra -i bash << EOF
  $Z_BASE_DIR/bin/zmcontrol restart
EOF
if [[ $? -ne 0 ]]; then
 echo "'zmcontrol restart' command failed"
 exit 1
fi
sudo -u zimbra -g zimbra -i bash << EOF
  $Z_BASE_DIR/bin/zmproxyctl reload
EOF
if [[ $? -ne 0 ]]; then
 echo "'zmproxyctl reload' command failed"
 exit 1
fi

$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < $MESSAGE_FILE
