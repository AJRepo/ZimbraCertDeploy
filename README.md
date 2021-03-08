# ZimbraCertDeploy
Letsencrypt Post-Renew Script customized for a Zimbra server

Typically saved to /etc/letsencrypt/renewal-hooks/deploy

Notes:


* The command "sudo -u zimbra -g zimbra zmcontrol restart" can take a while to execute, seemingly hanging at "Stopping zimlet webapp...". Wait times for have been seen even being 15 minutes long and reortedly is due to a MySQL/MariaDB setting ( https://forums.zimbra.org/viewtopic.php?t=63221 ). This script has a section that schedules restarts at 3am even if the certbot/letsencrypt renewal happens earlier.  If your server is set for UTC but actually in a different time zone this would need to be adjusted (if used).

* Is being used successfully on production commercial Zimbra versions 
  * * 8.8.15_GA_3895.UBUNTU18.64
  * * 8.8.15.GA.3869.UBUNTU18.64 

* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
