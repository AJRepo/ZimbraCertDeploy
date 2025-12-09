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

   * [Short Explanation](https://wiki.zimbra.com/wiki/Installing_a_LetsEncrypt_SSL_Certificate)

   * [Longer Explanation](https://postboxservices.com/blogs/post/lets-setup-zimbra-9-0-0-on-ubuntu-18-0-4-and-configure-letsencrypt-ssl-certificates-on-it)

   * Example:
      * `sudo certbot certonly --standalone -d MY_FQDN
    --preferred-challenges=http --agree-tos --email MYEMAIL --http-01-port=80`

Note: the port above is 80. Certbot uses this port which is ok because
Port 80 is an unused port for Zimbra.

Note: Do not use port 8080 for Certbot as that's already used by Zimbra.
Setup, FW,  NAT and/or Proxy apropriately to accept the port you use above

* Edit the file `50_ZimbraCertDeploy.sh` and set these variables:

   * `DEBUG` =1 to print more messages to stdout (default=0)

   * `RESTART_PLAN` to be "Now", "Later", or "Manual". When certbot gets a certificate:

      * Now: deploy to zimbra and restart zimbra immediately

      * Later: Send an email alert, Sleep until 3 am, and then continue.

      * Manual: Send an email alert and exit.

* Move (or create a link to) the file `50_ZimbraCertDeploy.sh` in `/etc/letsencrypt/renewal-hooks/deploy/`

* Check that certificate renewals are scheduled. Could be found as:
   * `cat /etc/cron.d/certbot`
   * `systemctl status certbot.timer`

* (optional) Put certbot into a `screen` to watch restarts

   * `systemctl edit certbot.service`

      * Have that page show as

```
[Service]
ExecStart=
ExecStart=/usr/bin/screen -dmS cert_renew /usr/bin/certbot -q renew
```

## Testing

The script `50_ZimbraCertDeploy.sh` can be run independently of certbot
assumging certbot has run at least once. To do so:

1. Run `certbot` to get a new or renewed certificate.

1. Run `sudo ./50_ZimbraCertDeploy.sh` to deploy that certificate.

Essentially you are just calling the script
just as it would be called as a renewal hook automatically
when placed in `/etc/letsencrypt/renewal-hooks/deploy/`.

## Notes

* This script assumes the following:

   * ONE certificate assigned to the Zimbra mail server

   * Certbot saves three PEM files cert.pem, chain.pem, fullchain.pem, privkey.pem.

   * Zimbra installation is to /opt/zimbra

   * Zimbra runs as user zimbra, group zimbra

* This script makes a backup of the old certificate PEM files in `/opt/zimbra/ssl/letsencrypt/bak.YYYMMDD.HHmm`

* The command `zmcontrol restart` sometimes hangs at `"Stopping zimlet webapp..."`

Wait times for a Zimbra restart have been reported as over 15 minutes!!
This is reortedly due to a MySQL/MariaDB setting [https://forums.zimbra.org/viewtopic.php?t=63221](https://forums.zimbra.org/viewtopic.php?t=63221).

* Sometimes `zmcontrol restart` will not restart all services for unknown reasons.

   * This is a Zimbra issue and not something related to this script.

   * To fix: Run `zmcontrol status` If some are "stopped" then run `zmcontrol restart`

This script been used successfully in production for years.
Only recently have been tracking versions on which it has
been tested/deployed.

* Used successfully on production Zimbra versions as reported by the browser in "User->about"
   * zcs-NETWORK-8.8.15\_GA\_3895 UBUNTU18\_64 ( and newer versions )

   * Server Version `10.1.13_GA_4837 (build 20251031144354)` ( and newer )

* Used successfully on production Zimbra versions as reported by "`zmcontrol -v`"

   * `Release 8.8.15.GA.3869.UBUNTU18.64 NETWORK edition` (and newer )
   * `Release 10.0.7.GA.4518.UBUNTU20_64 NETWORK edition.` (and newer )
   * `Release 10.1.0.GA.4633.UBUNTU20_64 NETWORK edition.` (and newer )

* Notes: it has been reported that in some cases the restart at the end
 does not complete and you have to login remotely and run "zmcontrol restart"

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL
THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY
DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

Afan Ottenheimer
