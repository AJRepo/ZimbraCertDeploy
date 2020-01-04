# ZimbraCertDeploy
Letsencrypt Post-Renew Script customized for a Zimbra server

Typically saved to /etc/letsencrypt/renewal-hooks/deploy

Notes:

* No guarantees of code fitness for this script.

* The command "sudo -u zimbra -g zimbra zmcontrol restart" can take a while to execute due to zimlet webapp taking a while to stop (e.g. 15 minutes) due to MySQL setting ( https://forums.zimbra.org/viewtopic.php?t=63221 ) so there's a commented out section that schedules restarts at 3am even if the certbot/letsencrypt renewal happens earlier.  If your server is set for UTC but actually in a different time zone this would need to be adjusted (if used).

