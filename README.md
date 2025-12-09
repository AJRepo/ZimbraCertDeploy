# ZimbraCertDeploy

Letsencrypt Post-Renew Script customized for a Zimbra server

This program automatically installs into Zimbra
the TLS certificate that has been downloaded by certbot

This script leverages the Certbot post-deploy hooks to
run automatically after certbot has renewed a
certificate, or it can be run independently.

When certbot renews certificates, it calls scripts
in `/etc/letsencrypt/renewal-hooks/deploy/` .

## Requrements

* Zimbra

* Certbot

* Bash

## Installation Process

* Install Zimbra Normally

* Install certbot (e.g. `apt install certbot`) on the Zimbra server.

* Install the certbot certificate once, manually. Some documentation:

  ** [Short Explanation](https://wiki.zimbra.com/wiki/Installing_a_LetsEncrypt_SSL_Certificate)
  ** [Longer Explanation](https://postboxservices.com/blogs/post/lets-setup-zimbra-9-0-0-on-ubuntu-18-0-4-and-configure-letsencrypt-ssl-certificates-on-it)

  ** Usually something like
'sudo certbot certonly --standalone -d MY\_FQDN
    --preferred-challenges=http --agree-tos --email MYEMAIL --http-01-port=80'

Note: the port above is 80. Certbot uses this port which is ok because
Port 80 is an unused port for Zimbra.

Note: Do not use port 8080 for Certbot as that's already used by Zimbra.
Setup, FW,  NAT and/or Proxy apropriately to accept the port you use above

* Edit the file 50\_ZimbraCertDeploy.sh to choose if you want the
deployment method (RESTART\_PLAN=) to be "Now", "Later", or "Manual"

  * Now = deploy and restart as soon as certobot gets a new certificate
  * Later = 3 am local server time, restart zimbra then
  * Manual = Don't deploy, just notify that a new certificate is downloaded and ready to deploy to Zimbra.

* Move (or create a link to) the file 50\_ZimbraCertDeploy.sh in `/etc/letsencrypt/renewal-hooks/deploy/`

* Check that certificate renewals are scheduled. Could be found as:
   * `more /etc/cron.d/certbot`
   * `systemctl status certbot.timer`

* (optional) Since you might want to check for hangs on restarting of Zimbra, put certbot into a screen by doing the following
   * `systemctl edit certbot.service`
   * In that edit page that comes up put and save the following
```
[Service]
ExecStart=
ExecStart=/usr/bin/screen -dmS cert_renew /usr/bin/certbot -q renew
```


## Testing

You can run the script 50\_ZimbraCertDeploy.sh after a certbot renewal has taken place. E.g. To test
`50_ZimbraCertDeploy.sh` separately from `certbot renew` do the following:

1. Run `certbot renew` to get a new certificate.

2. Run `sudo ./50_ZimbraCertDeploy.sh` to deploy that certificate.

Essentially you are just calling the script just as it would be called as a renewal hook automatically
when placed in `/etc/letsencrypt/renewal-hooks/deploy/`.


## Notes

* This script assumes the following:

  *  ONE certificate that's assigned to the Zimbra mail server with PEM files cert.pem, chain.pem, fullchain.pem, privkey.pem.

  * Zimbra installation is to /opt/zimbra

  * Zimbra runs as user zimbra, group zimbra

* It makes a backup of the old certificate PEM files in /opt/zimbra/ssl/letsencrypt/bak.YYYMMDD.HHmm before replacing those PEM files. Note
that the granularity of that is to the minute, not to the second.


* The command `sudo -u zimbra -g zimbra zmcontrol restart` can take a while to execute, seemingly hanging at "Stopping zimlet webapp...".
Wait times for a Zimbra restart have been reported as over 15 minutes. This is reortedly due to a MySQL/MariaDB setting ( https://forums.zimbra.org/viewtopic.php?t=63221 ). This script has a section that optionally schedules restarts at 3am Server Time even if the certbot/letsencrypt renewal happens earlier.  If your server is set for UTC but actually in a different time zone this would need to be adjusted (if used).

* Sometimes `zmcontrol restart` will just fail and not restart all services for unknown reasons. This is a Zimbra issue and not
something related to this script. If you run `zmcontrol status` it will show some services running and some stopped. I'm experimenting
with checking for that and re-running `zmcontrol restart` but just note that since it is the last command needed, if that's the state your
server is in, just run that restart command manually and you should be good to go.

Has been used successfully in production for years, but only recently have been tracking versions on which it has
been tested/deployed.

* Used successfully on production Zimbra versions as reported by the browser in "User->about"
  * zcs-NETWORK-8.8.15\_GA\_3895 UBUNTU18\_64 ( and newer versions of the 8.8.15 line)

* Used successfully on production Zimbra versions as reported by "`zmcontrol -v`"
  * "Release 8.8.15.GA.3869.UBUNTU18.64 UBUNTU18\_64 NETWORK edition, Patch 8.8.15\_P26" ( and newer versions of the 8.8.15 line)
  * "Release 10.0.7.GA.4518.UBUNTU20\_64 NETWORK edition." (and newer versions of the 10.0.X line)
  * "Release 10.1.0.GA.4633.UBUNTU20\_64 NETWORK edition." (and newer versions of the 10.1.X line)

* Notes: it has been reported that in some cases the restart at the end
 does not complete and you have to login remotely and run "zmcontrol restart"

* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Afan Ottenheimer
