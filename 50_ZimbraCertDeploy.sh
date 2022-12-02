#!/bin/bash

# Ignore SC2181 - required with sudo
# shellcheck disable=SC2181
# Assumes Single Server Installation

#Warning: hostname -A adds a space to the end of returned value(s)
FQDN=$(hostname -A | sed -e /\ /s///g)
DOMAIN=$(hostname -d | sed -e /\ /s///g)
FROM="<ZimbraMailServer@$FQDN"
EMAIL="postmaster@$DOMAIN"
Z_BASE_DIR="/opt/zimbra"
#X3_FILE=$Z_BASE_DIR/ssl/letsencrypt/lets-encrypt-x3-cross-signed.pem.txt
X1_FILE=$Z_BASE_DIR/ssl/letsencrypt/ISRG-X1.pem
THIS_SCRIPT=$(basename "${0}")
#If this is false, then the restart happens at 3 am (server time)
RESTART_NOW="False"


NOW_UNIXTIME=$(date +%s)
NOW_DATE=$(date)

#Note:
#	If certbot is using systemd.timer (not cron.d) then the actual files will be in 
#	/tmp/systemd-private-HASH-certbot.service-ID/tmp/50_ZimbraCertDeploy.sh.UNIXTIME.log
#	Where HASH is the id of the process. This means the /tmp dir for systemd.timer is
# deleted on script	exit even if the final restart was unsuccessful. 
#
LOG_FILE="$Z_BASE_DIR/log/$THIS_SCRIPT.$NOW_UNIXTIME.log"
MESSAGE_FILE="/tmp/message.$NOW_UNIXTIME.txt"
PROGRESS_FILE="/tmp/message.$NOW_UNIXTIME.txt.progress"

touch "$LOG_FILE" ||  echo "Cannot create $LOG_FILE" ; exit 1 

# Input:  None
# Output: None
# Return: 0 on success, non 0 otherwise
function restart_zimbra_if_not_running() {
	local _ret=

	_ret=1

	echo "In function restart_zimbra_if_not_running----" >> "$PROGRESS_FILE"
	echo "In function restart_zimbra_if_not_running----" >> "$LOG_FILE"
	echo "--" >> "$PROGRESS_FILE"
	echo "--" >> "$LOG_FILE"
	#Do a final check to make sure all zimbra services are running
	print_v i "--About to test running 'zmcontrol status'" >> "$LOG_FILE"
	print_v i "--About to test running 'zmcontrol status'" >> "$PROGRESS_FILE"
	sudo -u zimbra -g zimbra -i bash <<- EOF
		$Z_BASE_DIR/bin/zmcontrol status | grep -i Stopped >> $LOG_FILE 2>&1
	EOF

	#Did the grep find something "stopped" ?
	if [[ $? -eq 0 ]]; then
		print_v w "--Some Zimbra services are not running, running 'zmcontrol restart' again" >> "$LOG_FILE"
		print_v w "--Some Zimbra services are not running, running 'zmcontrol restart' again" >> "$PROGRESS_FILE"

		sudo -u zimbra -g zimbra -i bash <<- EOF
			$Z_BASE_DIR/bin/zmcontrol restart >> "$LOG_FILE" 2>&1
		EOF
		_ret=$?

		print_v i "--Second Restart Attempted 'zmcontrol restart' with result $?" >> "$LOG_FILE"
		print_v i "--Second Restart Attempted 'zmcontrol restart' with result $?" >> "$PROGRESS_FILE"
	else
		print_v i "--All Zimbra services are running" >> "$LOG_FILE"
		print_v i "--All Zimbra services are running" >> "$PROGRESS_FILE"
		print_v i "--" >> "$PROGRESS_FILE"
	fi
	print_v i "Exit function restart_zimbra_if_not_running with _ret=$_ret" >> "$PROGRESS_FILE"

	return $_ret
}

# Input:  None
# Output: None
# Return: 0 on success, non 0 otherwise
# Notes: sendmail won't succeed if Zimbra is not running, systemd tmp is deleted on script exit.
#		That means you need to keep logs in /opt/zimbra/log to see logs for an unsuccessful renewal.
function restart_zimbra() {
	local _ret=

	_ret=1
	print_v i "In function restart_zimbra----" >> "$PROGRESS_FILE"
	print_v i "In function restart_zimbra----" >> "$LOG_FILE"

	sudo -u zimbra -g zimbra -i bash <<- EOF
		$Z_BASE_DIR/bin/zmcontrol restart >> "$LOG_FILE" 2>&1
	EOF
  _ret=$?

	#Do not have any commands between this and zmcontrol restart above
	if [[ $_ret -ne 0 ]]; then
		print_v e "'zmcontrol restart' command failed" >> "$MESSAGE_FILE.errors"
		print_v e "'zmcontrol restart' command failed" >> "$LOG_FILE"
		#email the error log file, if zimbra isn't running, log sendmail stderr to $LOG_FILE
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
		#try again
		if ! restart_zimbra_if_not_running; then
			print_v e "'restart_zimbra_if_not_running failed" >> "$LOG_FILE"
			print_v e "'restart_zimbra_if_not_running failed" >> "$MESSAGE_FILE.errors"
			#email the error log file, if zimbra isn't running, log sendmail stderr to $LOG_FILE
			$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
			exit 1
		fi
	else
		print_v i "'zmcontrol restart' command success" >> "$PROGRESS_FILE"
		print_v i "'zmcontrol restart' command success" >> "$LOG_FILE"
	fi

	NOW_DATE=$(date)

	echo "Exit function restart_zimbra with _ret=$_ret" >> "$PROGRESS_FILE"
	return $_ret
}

# Input:  Message
# Output: Formatted Message String
# Return: 0 on success, non 0 otherwise
function print_v() {
	local level=$1
 	THIS_DATE=$(date --iso-8601=seconds)

	case $level in
		e) # Error
		echo -e "$THIS_DATE [ERRS] ${*:2}"
		;;
		w) # Warning
		echo -e "$THIS_DATE [WARN] ${*:2}"
		;;
		*) # Any other level
		echo -e "$THIS_DATE [INFO] ${*:2}"
		;;
	esac
}


if [[ $RESTART_NOW == "True" ]]; then
	RESTART_UNIXTIME=$NOW_UNIXTIME
else
	##Seconds until the next Mail Server Restart time (3am)
	if [[ $(date +%k) -gt 3 ]]; then
		RESTART_UNIXTIME=$(date +%s -d "3am tomorrow")
		RESTART_DATE=$(date -d "3am tomorrow")
		DAY_TEXT="Tomorrow"
	else
		RESTART_UNIXTIME=$(date +%s -d "3am")
		RESTART_DATE=$(date -d "3am")
		DAY_TEXT="Today"
	fi
fi

echo "Subject: Logfile: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>
To: <$EMAIL>


Starting Logfile $THIS_SCRIPT
Date: $NOW_DATE
RESTART_DATE: $RESTART_DATE
This file: $LOG_FILE" >> "$LOG_FILE"


#Options on not deploying to mail server immediately on certbot renew execution
## Option 1: Specify restart time (e.g. Have restart time a geopts option)
## Option 2: Modify letsencrypt cron script
## Option 3: Create systemd monitor which watches both letsencrypt and Zimbra cert dirs

SECONDS_TIL_START=$(echo "$RESTART_UNIXTIME - $NOW_UNIXTIME" | bc)
if [[ $SECONDS_TIL_START == "" || $SECONDS_TIL_START -le 0 ]]; then
	SECONDS_TIL_START=10
fi

print_v i "SECONDS_TIL_START: $SECONDS_TIL_START" >> "$LOG_FILE"

########SETUP MESSAGE FILE FOR ERRORS######
echo "Subject: ERRORS: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>
To: <$EMAIL>

Zimbra Error Messages: " > "$MESSAGE_FILE.errors"
######################################

if ! touch "$LOG_FILE"; then
	print_v e "Error: Cannot create $LOG_FILE" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit
fi
######################################

if ! touch "$PROGRESS_FILE"; then
	print_v e "Error: Cannot create $PROGRESS_FILE" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit
fi
######################################


########NOTIFY ABOUT SCRIPT STARTING
echo "Subject: Letsencrypt Renewal of Zimbra Cert starting
From: <$FROM>

The Zimbra Server's Letsencrypt Certificate has been renewed and downloaded but
not yet deployed to the Zimbra mail service.

Current Unixtime: $NOW_UNIXTIME ($NOW_DATE)

If a restart time was set in the script then this script would sleep until
Restart Unixtime: $RESTART_UNIXTIME ($RESTART_DATE $DAY_TEXT)

Now sleeping for $SECONDS_TIL_START seconds before continuing this script which
will deploy the certbot certificate to Zimbra and restart the server.

The file for error messages related to this process will be $MESSAGE_FILE.errors

If you are using systemd then the above log file will actually be in 
/tmp/systemd-private-HASH-certbot.service-ID/$MESSAGE_FILE.errors

The file for progress messages related to this process will be $PROGRESS_FILE

If you are using systemd then the above log file will actually be in 
/tmp/systemd-private-HASH-certbot.service-ID/$PROGRESS_FILE

The log file for this process will be $LOG_FILE

If you are using systemd then temp files will actually be in 
/tmp/systemd-private-HASH-certbot.service-ID/

This message generated by $THIS_SCRIPT" > "$MESSAGE_FILE.start"

if [[ -f "$Z_BASE_DIR/common/sbin/sendmail" ]]; then 
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.start"
else
	print_v e "Error: Can't find $Z_BASE_DIR/common/sbin/sendmail. Exiting."
	exit 1
fi
#####################################
sleep "$SECONDS_TIL_START"

echo "Subject: Letsencrypt Renewal of Zimbra Cert progress
From: <$FROM>

Zimbra Certificate Renewal progress
This file is $PROGRESS_FILE

Note: If you are using systemd then the above log file will actually be in 
/tmp/systemd-private-HASH-certbot.service-ID/$PROGRESS_FILE

This message generated by $THIS_SCRIPT" > "$PROGRESS_FILE"

TODAY=$(date +%Y%m%d)

#echo "EXITING FOR DEBUGGING"
#exit

#Make Backup Directory
print_v i "Make Backup Directory" >> "$LOG_FILE"
mkdir -p "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY"
if [[ $(  mkdir -p "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY") -ne 0 ]]; then
	print_v e "   Unable to make backup directory" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
fi
chown zimbra:zimbra "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAY"


#Backup Old Cert
print_v i "Backup Old Cert" >> "$LOG_FILE"
if [[ $(cp $Z_BASE_DIR/ssl/letsencrypt/*.pem $Z_BASE_DIR/ssl/letsencrypt/bak."$TODAY"/) -ne 0 ]]; then
	print_v e "   Unable to backup old Certiricate, stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
fi

#Copy New Cert
print_v i "Copy New Cert" >> "$LOG_FILE"
if [[ $(cp /etc/letsencrypt/live/"$FQDN"/* $Z_BASE_DIR/ssl/letsencrypt/) -ne 0 ]]; then
	print_v e "   Unable to copy new Certiricate to $Z_BASE_DIR/ssl/letsencrypt, stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
fi

#Chaining Cert
#https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt
#https://letsencrypt.org/certs/letsencryptauthorityx3.pem.txt
#https://letsencrypt.org/certs/trustid-x3-root.pem.txt

#X1 Cert Chaining
X1CERTURI="https://letsencrypt.org/certs/isrgrootx1.pem.txt"
print_v i "X1 Cert Chaining" >> "$LOG_FILE"
if [[ $(wget -o /tmp/ISRG-X1.pem.log -O /tmp/ISRG-X1.pem $X1CERTURI) -ne 0 ]]; then
	print_v w "WARNING: Unable to download X1 Cross Signed Cert" >> "$MESSAGE_FILE.errors"
	print_v w "WARNING: Unable to download X1 Cross Signed Cert" >> "$PROGRESS_FILE"
	echo "Subject: WARNING: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>

	Unable to download X1 Cross Signed Cert" > "$MESSAGE_FILE.warning"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.warning"
fi

if [[ -f "$X1_FILE" ]]; then
	#compare to see if X1 Cert changed
	if [[ $(diff /tmp/ISRG-X1.pem $X1_FILE) -ne 0 ]]; then
		echo "WARNING: The downloaded X1 Cross Signed Cert differs from what was saved previously.
		This might be ok if this is the first time you've run this program or if it actually changed
		but flagging anyway." >> "$PROGRESS_FILE"
	fi
else
	cp /tmp/ISRG-X1.pem $Z_BASE_DIR/ssl/letsencrypt/
	chown zimbra:zimbra $X1_FILE
fi

if [[ -f "$X1_FILE" && -f "$Z_BASE_DIR/ssl/letsencrypt/chain.pem" ]]; then
	#put $X1_FILE first in chain.pem
	cat "$X1_FILE" "$Z_BASE_DIR/ssl/letsencrypt/chain.pem" > /tmp/certtmp.pem
	mv /tmp/certtmp.pem "$Z_BASE_DIR/ssl/letsencrypt/chain.pem"
	chown zimbra:zimbra $Z_BASE_DIR/ssl/letsencrypt/*
else
	echo " $X1_FILE or chain.pem file missing. stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
fi

################Note X3 Expires 2021-09-30
#X3CERTURI="https://letsencrypt.org/certs/trustid-x3-root.pem.txt"
##X3 Cert chaining
#print_v i "X3 Cert Chaining" >> "$LOG_FILE"
#if [[ $(wget -o /tmp/lets-encrypt-x3-cross-signed.pem.log -O /tmp/lets-encrypt-x3-cross-signed.pem.txt $X3CERTURI) -ne 0 ]]; then
#	echo "WARNING: Unable to download X3 Cross Signed Cert" >> "$PROGRESS_FILE"
#	echo "Subject: WARNING: Letsencrypt Renewal of Zimbra Cert
#From: <$FROM>
#
#	Unable to download X3 Cross Signed Cert" > "$MESSAGE_FILE.warning"
#	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.warning"
#fi
#
#if [[ -f "$X3_FILE" ]]; then
#	#compare to see if X3 Cert changed
#	if [[ $(diff /tmp/lets-encrypt-x3-cross-signed.pem.txt $X3_FILE) -ne 0 ]]; then
#		echo "WARNING: The downloaded X3 Cross Signed Cert differs from what was saved previously.
#		This might be ok if this is the first time you've run this program or if it actually changed
#		but flagging anyway." >> "$PROGRESS_FILE"
#	fi
#else
#	cp /tmp/lets-encrypt-x3-cross-signed.pem.txt $Z_BASE_DIR/ssl/letsencrypt/
#	chown zimbra:zimbra $X3_FILE
#fi
#
#if [[ -f "$X3_FILE" && -f "$Z_BASE_DIR/ssl/letsencrypt/chain.pem" ]]; then
#	cat $X3_FILE >> $Z_BASE_DIR/ssl/letsencrypt/chain.pem
#	chown zimbra:zimbra $Z_BASE_DIR/ssl/letsencrypt/*
#else
#	echo " $X3_FILE or chain.pem file missing. stopping" >> "$MESSAGE_FILE.errors"
#	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors"
#	exit 1
#fi
##############X3 Expires#######################

cd $Z_BASE_DIR/ssl/letsencrypt/ || exit 1
#Check Certificates Prior to Deploy
print_v i "Check Certs Prior to Deploy" >> "$LOG_FILE"
sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmcertmgr verifycrt comm $Z_BASE_DIR/ssl/letsencrypt/privkey.pem $Z_BASE_DIR/ssl/letsencrypt/cert.pem $Z_BASE_DIR/ssl/letsencrypt/chain.pem
EOF

if [[ $? -ne 0 ]]; then
	echo "'zmcertmgr verifycert comm' command failed"
	echo "   Check of certificate failed. stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
fi

#Deploy and Restart
print_v i "Check Certs Prior to Deploy" >> "$LOG_FILE"
echo "About to run 'zmproxyctl stop'" >> "$PROGRESS_FILE"
sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmproxyctl stop
EOF

if [[ $? -ne 0 ]]; then
	print_v e "'zmproxyctl stop' command failed"
	print_v e "'zmproxyctl stop' command failed" >> "$LOG_FILE"
	print_v e "'zmproxyctl stop' command failed" >> "$PROGRESS_FILE"
	exit 1
fi

print_v i "About to run 'zmmailboxdctl stop'" >> "$LOG_FILE"
print_v i "About to run 'zmmailboxdctl stop'" >> "$PROGRESS_FILE"
sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmmailboxdctl stop
EOF

if [[ $? -ne 0 ]]; then
	print_v e "'zmmailboxdctl stop' command failed"
	print_v e "'zmmailboxdctl stop' command failed" >> "$LOG_FILE"
	print_v e "'zmmailboxdctl stop' command failed" >> "$PROGRESS_FILE"
	exit 1
fi

#backup zimbra certs
print_v i "About to backup Zimbra Certs" >> "$LOG_FILE"
echo "About to backup Zimbra Certs" >> "$PROGRESS_FILE"
cp -r $Z_BASE_DIR/ssl/zimbra $Z_BASE_DIR/ssl/zimbra."$TODAY"
chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra."$TODAY"

#Is $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key a softlink to privkey.pem?
if [[ -h $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key ]]; then
	#check that link goes to correct spot
	COMM_KEY=$(readlink -f $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key)
	if [[ $COMM_KEY != "$Z_BASE_DIR/ssl/letsencrypt/privkey.pem" ]]; then
		echo "ERROR: link goes to wrong place, Exiting"
		print_v e "ERROR: link goes to wrong place, Exiting" >> "$MESSAGE_FILE.errors"
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
		exit 1
	fi
else
	if [[ $(cp $Z_BASE_DIR/ssl/letsencrypt/privkey.pem $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key) -ne 0 ]]; then
		echo "   Copy of privkey.pem to commercial.key failed. stopping" >> "$MESSAGE_FILE.errors"
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
		exit 1
	fi
	chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key
fi

#Deploy Certificate
NOW_DATE=$(date)
print_v i "About to Deploy 'zmcertmgr deploycrt comm at $NOW_DATE'" >> "$LOG_FILE"
echo "About to Deploy 'zmcertmgr deploycrt comm at $NOW_DATE'" >> "$PROGRESS_FILE"
sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmcertmgr deploycrt comm $Z_BASE_DIR/ssl/letsencrypt/cert.pem $Z_BASE_DIR/ssl/letsencrypt/chain.pem
EOF

if [[ $? -ne 0 ]]; then
	echo "'certmgr deploycrt comm' command failed"
	echo "'certmgr deploycrt comm' command failed" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
else
	print_v i "'certmgr deploycrt comm' command success" >> "$LOG_FILE"
	echo "'certmgr deploycrt comm' command success" >> "$PROGRESS_FILE"
fi

#Now that certificate is deployed restart services
NOW_DATE=$(date)
echo "Emailing progress right before restarting services at $NOW_DATE" >> "$PROGRESS_FILE"
$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$PROGRESS_FILE"

#have to wait 60 seconds or so for zimlet to restart so best to do this at night
print_v i "About to restart 'zmcontrol restart' at $NOW_DATE" >> "$LOG_FILE"
echo "About to restart 'zmcontrol restart' at $NOW_DATE" >> "$PROGRESS_FILE"
restart_zimbra
echo "Command Complete 'zmcontrol restart' at $NOW_DATE" >> "$PROGRESS_FILE"
print_v i "Command Complete 'zmcontrol restart' at $NOW_DATE" >> "$LOG_FILE"

echo "----" >> "$PROGRESS_FILE"

echo "About to restart proxy 'zmproxyctl reload' at $NOW_DATE" >> "$PROGRESS_FILE"
print_v i "About to restart proxy 'zmproxyctl reload' at $NOW_DATE" >> "$LOG_FILE"
sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmproxyctl reload
EOF

#Do not have any commands between this and zmproxyctl reload above
if [[ $? -ne 0 ]]; then
	echo "'zmproxyctl reload' command failed"
	echo "'zmproxyctl reload' command failed" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$MESSAGE_FILE.errors"
	exit 1
else
	echo "'zmproxyctl reload' command success" >> "$PROGRESS_FILE"
fi

print_v i "All done. About to send message of completion" >> "$LOG_FILE"
echo "----" >> "$PROGRESS_FILE"
echo "All done. About to send message of completion" >> "$PROGRESS_FILE"
$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$PROGRESS_FILE"

#have to wait 60 seconds or so for zimlet to restart so best to do this at night
print_v i "About to restart 'zmcontrol restart' " >> "$LOG_FILE"
print_v i "About to restart 'zmcontrol restart' " >> "$PROGRESS_FILE"
restart_zimbra
print_v i "Command Complete 'zmcontrol restart' " >> "$PROGRESS_FILE"
print_v i "Command Complete 'zmcontrol restart' " >> "$LOG_FILE"


echo "----" >> "$PROGRESS_FILE"
echo "About to sleep 15 seconds" >> "$PROGRESS_FILE"
#Sleep 15 seconds before testing status
sleep 15

restart_zimbra_if_not_running

#Email progress report
$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$PROGRESS_FILE"

#Do we believe that all services are running? Let's check again in 5 minutes. 
echo "About to sleep for 5 minutes to check " >> "$PROGRESS_FILE"
sleep 300
#Email progress report
restart_zimbra_if_not_running

$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" >> "$LOG_FILE" 2>&1 < "$PROGRESS_FILE"

#END MAIN
################


#Note: Must use tabs instead of spaces for heredoc (<<-) to work
# vim: tabstop=2 shiftwidth=2 noexpandtab
