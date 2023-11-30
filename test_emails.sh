#!/bin/bash
# Author: AJRepo
# License: GPLv3
# Version: 4.5

#This test script runs zmcontrol status and looks for running or stopped services
# then sends you an email about it. Run this script as a test to make sure
# you can get alerts from your Zimbra machine.
# TESTS:
# * Can run as user zimbra
# * Can get emails
# * Can make backup directory
# * Can run verifycrt ok


DEBUG=1

# Ignore SC2181 - required with sudo
# shellcheck disable=SC2181
# Assumes Single Server Installation

#Warning: hostname -A adds a space to the end of returned value(s)
MY_PID=$$
FQDN=$(hostname -A | sed -e /\ /s///g)
DOMAIN=$(hostname -d | sed -e /\ /s///g)
FROM="<ZimbraMailServer@$FQDN"
EMAIL="postmaster@$DOMAIN"
Z_BASE_DIR="/opt/zimbra"
#X3_FILE=$Z_BASE_DIR/ssl/letsencrypt/lets-encrypt-x3-cross-signed.pem.txt
THIS_SCRIPT=$(basename "${0}")

#Restart can be "Now", or "Manual" if anything else will restart at 3 am
RESTART_PLAN="NONE: testing"


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

# Input:  Message
# Output: Formatted Message String
# Return: 0 on success, non 0 otherwise
function print_v() {
	local level=$1
	THIS_DATE=$(date --iso-8601=seconds)

	case $level in
		d) # Debug
		echo -e "$THIS_DATE [DBUG] ${*:2}"
		;;
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


if [[ $DEBUG == "1" ]]; then
	print_v d "--About to start program"
	print_v d "LOG_FILE=$LOG_FILE"
fi

#one cannot use
# cmd || (cmd2; exit)
#because the exit in the () only exits the sub shell () not this script
if ! touch "$LOG_FILE"; then
	print_v e "--Cannot create $LOG_FILE"
	exit 1
fi

if ! chown zimbra.zimbra "$LOG_FILE"; then
	print_v e "--Cannot run command 'chown zimbra.zimbra $LOG_FILE'"
	exit 1
fi

if [[ $DEBUG == "1" ]]; then
	print_v d "--Touch log file ok"
fi

# Input:  None
# Output: None
# Return: 0 on success, non 0 otherwise
function test_zimbra_running() {
	local _ret=

	_ret=1
	print_v i "In function test_zimbra_running----" | tee -a "$PROGRESS_FILE" "$LOG_FILE"
	echo "--Echo file=$PROGRESS_FILE: In test_zimbra_running--" | tee -a "$PROGRESS_FILE" "$LOG_FILE"

	#Do a final check to make sure all zimbra services are running
	print_v i "--About to test running 'zmcontrol status'" | tee -a "$PROGRESS_FILE" "$LOG_FILE"
	#NOTE: log file must be owned by zimbra if you run this command as 'sudo -u zimbra...'

	if [[ $DEBUG == "1" ]]; then
		print_v i "TESTING zmcontrol status to $LOG_FILE, $PROGRESS_FILE"
	fi

	sudo -u zimbra -g zimbra -i bash <<- EOF
		#Since bash 4 you can replace "2&>1 |" with |&
		$Z_BASE_DIR/bin/zmcontrol status |& tee -a $LOG_FILE $PROGRESS_FILE | grep -i Stopped
	EOF

	#Did the grep find something "stopped" ?
	# shellcheck disable=SC2181
	if [[ $? -eq 0 ]]; then
		_ret=1
		print_v w "--TEST: Some Zimbra services are not running" >> "$LOG_FILE"
		print_v w "--TEST: Some Zimbra services are not running" >> "$PROGRESS_FILE"
	else
		_ret=0
	fi
}

# Input:  None
# Output: None
# Return: 0 on success, non 0 otherwise
function restart_zimbra_if_not_running() {
	local _ret=

	_ret=1

	print_v i "In function restart_zimbra_if_not_running----" >> "$PROGRESS_FILE"
	print_v i "In function restart_zimbra_if_not_running----" >> "$LOG_FILE"
	echo "--Echo file=$PROGRESS_FILE: In restart_zimbra_if_not_running--" >> "$PROGRESS_FILE"
	echo "--Echo file=$LOG_FILE: In restart_zimbra_if_not_running--" >> "$LOG_FILE"
	#Do a final check to make sure all zimbra services are running
	print_v i "--About to test running 'zmcontrol status'" >> "$LOG_FILE"
	print_v i "--About to test running 'zmcontrol status'" >> "$PROGRESS_FILE"
	
	if ! test_zimbra_running; then
		print_v w "--TEST: Some Zimbra services are not running, running 'zmcontrol restart' again" >> "$LOG_FILE"
		print_v w "--TEST: Some Zimbra services are not running, running 'zmcontrol restart' again" >> "$PROGRESS_FILE"

		sudo -u zimbra -g zimbra -i bash <<- EOF
			$Z_BASE_DIR/bin/zmcontrol restart >> "$LOG_FILE" 2>&1
		EOF
		_ret=$?

		print_v i "--Second Restart Attempted 'zmcontrol restart' with result $?" >> "$LOG_FILE"
		print_v i "--Second Restart Attempted 'zmcontrol restart' with result $?" >> "$PROGRESS_FILE"
	else
		_ret=0
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
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
		#try again
		if ! restart_zimbra_if_not_running; then
			print_v e "'restart_zimbra_if_not_running failed" >> "$LOG_FILE"
			print_v e "'restart_zimbra_if_not_running failed" >> "$MESSAGE_FILE.errors"
			#email the error log file, if zimbra isn't running, log sendmail stderr to $LOG_FILE
			$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
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


###########MAIN################################

if [[ $DEBUG == "1" ]]; then
	print_v d "--RESTART_PLAN=$RESTART_PLAN"
fi

echo "Subject: Logfile: TESTING Letsencrypt Renewal of Zimbra Cert
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

SECONDS_TIL_START=10

print_v i "SECONDS_TIL_START: $SECONDS_TIL_START" >> "$LOG_FILE"

########SETUP MESSAGE FILE FOR ERRORS######
echo "Subject: TESTING ERRORS: Letsencrypt Renewal of Zimbra Cert
From: <$FROM>
To: <$EMAIL>

Zimbra Error Messages: " > "$MESSAGE_FILE.errors"
######################################

if ! touch "$LOG_FILE"; then
	print_v e "Error: Cannot create $LOG_FILE" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
	exit
fi
######################################

if ! touch "$PROGRESS_FILE"; then
	print_v e "Error: Cannot create $PROGRESS_FILE" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
	exit
fi
######################################

########NOT MANUAL: CONTINUE AND NOTIFY ABOUT SCRIPT STARTING
echo "Subject: TESTING: Letsencrypt Test Script
From: <$FROM>

Testing Script

Current Unixtime: $NOW_UNIXTIME ($NOW_DATE)

Script name: $0
Script Args: $1

Script PID: $MY_PID

About to sleep for $SECONDS_TIL_START seconds before continuing this script which
will test emails and Zimbra Status

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

#####################################


TODAYMIN=$(date +%Y%m%d%H%M)

#####################################
# Warn about upcoming backup
#####################################

$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.start" |& tee -a "$LOG_FILE"


#####################################
# Sleep and then start the backup
#####################################

sleep "$SECONDS_TIL_START"


echo "Subject: TESTING: Letsencrypt Testing of Service part 2
From: <$FROM>

This file is $PROGRESS_FILE

Finished sleeping $SECONDS_TIL_START

Now continuing with the test

Note: If you are using systemd then the above log file will actually be in
/tmp/systemd-private-HASH-certbot.service-ID/$PROGRESS_FILE

This message generated by $THIS_SCRIPT" > "$PROGRESS_FILE"

#Make Backup Directory
print_v i "Make Backup Directory" >> "$LOG_FILE"
if !  mkdir -p "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAYMIN"; then
	print_v e "   Unable to make backup directory" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
	exit 1
fi
chown zimbra:zimbra "$Z_BASE_DIR/ssl/letsencrypt/bak.$TODAYMIN"


#Backup Old Cert
print_v i "Backup Old Cert" >> "$LOG_FILE"
if ! cp $Z_BASE_DIR/ssl/letsencrypt/*.pem $Z_BASE_DIR/ssl/letsencrypt/bak."$TODAYMIN"/; then
	print_v e "   Unable to backup old Certiricate, stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
	exit 1
fi

##############X3 Expires#######################

sudo -u zimbra -g zimbra -i bash << EOF
	$Z_BASE_DIR/bin/zmcertmgr verifycrt comm $Z_BASE_DIR/ssl/letsencrypt/privkey.pem $Z_BASE_DIR/ssl/letsencrypt/cert.pem $Z_BASE_DIR/ssl/letsencrypt/chain.pem
EOF

# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	echo "'zmcertmgr verifycert comm' command failed"
	echo "   Check of certificate failed. stopping" >> "$MESSAGE_FILE.errors"
	$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
	exit 1
fi

#backup zimbra certs
print_v i "About to backup Zimbra Certs" >> "$LOG_FILE"
echo "About to backup Zimbra Certs" >> "$PROGRESS_FILE"
if ! cp -r $Z_BASE_DIR/ssl/zimbra $Z_BASE_DIR/ssl/zimbra."$TODAYMIN"; then
	echo "Can't backup $Z_BASE_DIR/ssl/zimbra to $Z_BASE_DIR/ssl/zimbra.$TODAYMIN"
	exit 1
fi
chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra."$TODAYMIN"

#Is $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key a softlink to privkey.pem?
if [[ -h $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key ]]; then
	#check that link goes to correct spot
	COMM_KEY=$(readlink -f $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key)
	if [[ $COMM_KEY != "$Z_BASE_DIR/ssl/letsencrypt/privkey.pem" ]]; then
		echo "ERROR: link goes to wrong place, Exiting"
		print_v e "ERROR: link goes to wrong place, Exiting" >> "$MESSAGE_FILE.errors"
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
		exit 1
	fi
else
	if ! chown zimbra:zimbra $Z_BASE_DIR/ssl/zimbra/commercial/commercial.key; then
		echo "ERROR: unable to chown zimbra commercial.key" >> "$MESSAGE_FILE.errors"
		print_v e "ERROR: unable to chown zimbra commercial.key, Exiting" >> "$MESSAGE_FILE.errors"
		$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$MESSAGE_FILE.errors" |& tee -a "$LOG_FILE"
		exit 1
	fi
fi

NOW_DATE=$(date)

echo "----" >> "$PROGRESS_FILE"

if ! test_zimbra_running; then
	echo "Test failed for testing zimbra running at $NOW_DATE" >> "$PROGRESS_FILE"
	print_v e "ERROR: Test failed for testing zimbra running at $NOW_DATE" >> "$PROGRESS_FILE"
else
	echo "Test succeeded for testing zimbra running at $NOW_DATE" >> "$PROGRESS_FILE"
	print_v i "SUCCESS: Test OK for testing zimbra running at $NOW_DATE" >> "$PROGRESS_FILE"
fi

print_v i "--About to exit program and email progress file $PROGRESS_FILE" >> "$LOG_FILE"
print_v i "--About to exit program and email progress file $PROGRESS_FILE" >> "$PROGRESS_FILE"
$Z_BASE_DIR/common/sbin/sendmail -t "$EMAIL" < "$PROGRESS_FILE" |& tee -a "$LOG_FILE"
print_v i "--Exit program" >> "$LOG_FILE"

#END MAIN
################


#Note: Must use tabs instead of spaces for heredoc (<<-) to work
# vim: tabstop=2 shiftwidth=2 noexpandtab
