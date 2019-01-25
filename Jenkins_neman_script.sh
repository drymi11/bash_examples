###This script starts newman API tests for DEV server. Newman API tests not included###

#!/bin/bash
SSHKEY="/var/lib/jenkins/keys/ssh_key"
DEVNODE="1.2.3.4" #DEV_NODE
QANODE="5.6.7.8" #QA_NODE
USER="ec2-user"
DB_USER="some_db_user"
DB_PASSWORD="12345" #in the real life this is Jenkins parameter, but here I must add this workaround, to make this script valid
REMOTEEXEC_QA="ssh -tt -i "$SSHKEY" "$USER"@"$QANODE""
REMOTEEXEC_DEV="ssh -tt -i "$SSHKEY" "$USER"@"$DEVNODE""
MYSQL_LINE="mysql --user="$DB_USER" --password="$DB_PASSWORD" --host=some_valid_db_url.us-west-2.rds.amazonaws.com"

refresh_db() { 
        $REMOTEEXEC_DEV 'sudo systemctl stop some-backend-api' 
        sleep 5s #In the perfect world, here must be check, is backend stopped, but I'm pretty sure, that 5s is enough for it.
        $REMOTEEXEC_QA $MYSQL_LINE --ececute="DROP DATABASE apitest;" #Why I'm not call database directly? Because it accessible only from QA server IP
        $REMOTEEXEC_QA $MYSQL_LINE --execute="CREATE DATABASE apitest collate utf8_unicode_ci;"
        $REMOTEEXEC_QA $MYSQL_LINE apitest < "/home/ec2-user/db_backups/apitest.sql"
        sleep 10s #see comment on line #16
        $REMOTEEXEC_DEV 'sudo systemctl start adept-backend-api'
        sleep 30s #see comment on line #16
} #this function rolling-out reference database from backup


rm -f ./newman/* #clearing up results from previous tests
rm -f ./newman.zip

refresh_db

OIFS="$IFS" #Hereinafter terrible workaround allowing parse all test names with bash (yes, I'm learning Python now)
IFS=$'\n'
for line in `find -not -path '.\*' -type f -name '*.json' -printf "%f\n" | sort -h`; do
if [ -z `echo "$line" | grep -e '^ZCDB'` ] #If the filename begins with "ZCDB", I must refresh DB before test started
then
        newman run "$line" -x -r cli,html --reporter-html-export newman/"$line".html
else
                IFS="$OIFS" #Without this
                refresh_db
                newman run "$line" -x -r cli,html --reporter-html-export newman/"$line".html
                OIFS="$IFS"
                IFS=$'\n'
fi
done
IFS="$OIFS"
zip -r newman.zip newman/ #Preparing test results, to send them by e-mail
