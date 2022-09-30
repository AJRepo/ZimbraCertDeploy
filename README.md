# ZimbraCertDeploy
Letsencrypt Post-Renew Script customized for a Zimbra server

This is designed to install a TLS certificate directly on the Zimbra mail server. It is
good to have a valid certificate on each Zimbra mail server even if that's not the
certificate seen by browsers (e.g. if you use HaProxy or the like between clients and
the server).

# Installation Process

* Install Zimbra Normally

* Install certbot (e.g. `apt install certbot`) on the Zimbra server.

* Install the certbot certificate once manually following https://wiki.zimbra.com/wiki/Installing_a_LetsEncrypt_SSL_Certificate  (longer explanation at https://postboxservices.com/blogs/post/lets-setup-zimbra-9-0-0-on-ubuntu-18-0-4-and-configure-letsencrypt-ssl-certificates-on-it  but your installation of certbot is better done via "apt install certbot" )

* Move the file 50_ZimbraCertDeploy.sh to `/etc/letsencrypt/renewal-hooks/deploy/`

* Check that certificate renewals are scheduled (e.g. `systemctl status certbot.timer`)

When certbot renews certificates, it will call any scripts you've put in `/etc/letsencrypt/renewal-hooks/deploy/` .


#Notes:

* This assumes ONE certificate that's assigned to the Zimbra mail server with PEM files cert.pem, chain.pem, fullchain.pem, privkey.pem.

* It makes a backup of the old certificate PEM files in /opt/zimbra/ssl/letsencrypt/bak.YYYMMDD before replacing those PEM files. Note
that the granularity of that is to the day, not to the second.


* The command `sudo -u zimbra -g zimbra zmcontrol restart` can take a while to execute, seemingly hanging at "Stopping zimlet webapp...". Wait times for have been seen even being 15 minutes long and reortedly is due to a MySQL/MariaDB setting ( https://forums.zimbra.org/viewtopic.php?t=63221 ). This script has a section that schedules restarts at 3am even if the certbot/letsencrypt renewal happens earlier.  If your server is set for UTC but actually in a different time zone this would need to be adjusted (if used).

* Sometimes `zmcontrol restart` will just fail and not restart all services for unknown reasons. This is a Zimbra issue and not
something related to this script. If you run `zmcontrol status` it will show some services running and some stopped. I'm experimenting
with checking for that and re-running `zmcontrol restart` but just note that since it is the last command needed, if that's the state your
server is in, just run that restart command manually and you should be good to go.

Has been used successfully in production for years, but only recently have been tracking versions on which it has
been tested/deployed.

* Used successfully on production Zimbra versions as reported by the browser in "User->about"
  * zcs-NETWORK-8.8.15_GA_3895 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_3869 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_3980 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_3996 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4007 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4125 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4156 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4173 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4232 UBUNTU18_64
  * zcs-NETWORK-8.8.15_GA_4272 UBUNTU18_64


* Used successfully on production Zimbra versions as reported by "`zmcontrol -v`"
  * "Release 8.8.15.GA.3869.UBUNTU18.64 UBUNTU18_64 NETWORK edition, Patch 8.8.15_P26"
  * "Release 8.8.15.GA.3869.UBUNTU18.64 UBUNTU18_64 NETWORK edition, Patch 8.8.15_P30"


* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
