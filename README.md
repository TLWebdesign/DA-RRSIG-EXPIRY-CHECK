# DA RRSIG Expiry Check
DirectAdmin bash script to check for (soon to be) expired RRSIG's in the signed zone files. 

## Instructions
### Download
Download the file somewhere on your system. I chose to download it to /usr/local/bin/check-expired-rrsig/

### Then make the file executable
chmod +x check_expired_rrsig.sh

### Create cron or execute manually

Without debug all domains: ./check_expired_rrsig.sh
With Debug all domains: ./check_expired_rrsig.sh true
Domain specific without debug: ./check_expired_rrsig.sh domain.nl false
Domain specific with debug: ./check_expired_rrsig.sh domain.nl true

If you enable debug you'll get a notification regardless. If debug is turned off you'll only get notified if it finds RRSIGS that are expired, soon to be expired or invalid.

**Be careful running debug with no domain specification as it will result in one message in your profile for every domain it reads. That could turn out to be a lot of messages!**