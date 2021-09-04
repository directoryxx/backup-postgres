#!/bin/bash

HOSTNAME=..
USERNAME=..
PASSWORD=..
DATABASE=crm
HOOKS=https://hooks.slack.com/services/..
TOKEN=..
CHANNEL="#backup"
CONTAINER=postgres-temp

export PGPASSWORD="$PASSWORD"
COUNTUSER=$(psql -P format=wrapped  -T -X -A -U ${USERNAME} -h ${HOSTNAME} -d ${DATABASE} -c 'SELECT COUNT(*) FROM users')

echo "Start Backup Master"
curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":thunder_cloud_and_rain: Start backup: $(date +%Y-%m-%d) \",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS

curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":thunder_cloud_and_rain: Pulling data: $(date +%Y-%m-%d) \",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS
# Note that we are setting the password to a global environment variable temporarily.
echo "Pulling Database: This may take a few minutes"
pg_dump -F t -h $HOSTNAME -U $USERNAME $DATABASE > $(date +%Y-%m-%d).backup
unset PGPASSWORD
gzip $(date +%Y-%m-%d).backup
echo "Pull Complete"
echo "Clearing old backups"
find . -type f -iname '*.backup.gz' -ctime +15 -not -name '????-??-01.backup.gz' -delete
echo "Clearing Complete"
curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":thunder_cloud_and_rain: Trying to upload backup: $(date +%Y-%m-%d) \",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS

FILENAME="/backup/"$(date +%Y-%m-%d).backup.gz
SHORTFILE=$(date +%Y-%m-%d).backup.gz

eval curl -s --form-string channels=${CHANNEL} -F file=@${FILENAME} -F filename=${FILENAME} -F token=${TOKEN} https://slack.com/api/files.upload
curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":sunny: Done Uploading Backup : $(date +%Y-%m-%d)\",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS

curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":thunder_cloud_and_rain: Starting Temporary Container : $(date +%Y-%m-%d)\",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS

docker run --name $CONTAINER -e POSTGRES_DB=$DATABASE -e POSTGRES_USER=$USERNAME -e POSTGRES_PASSWORD=$PASSWORD -p 127.0.0.1:5490:5432 -d postgres:12

docker exec $CONTAINER mkdir /test

docker cp $(date +%Y-%m-%d).backup.gz $CONTAINER:/test/$(date +%Y-%m-%d).backup.gz

docker exec $CONTAINER gunzip /test/$(date +%Y-%m-%d).backup.gz

sleep 5

docker exec  $CONTAINER pg_restore -U crm_user -d crm -1  /test/$(date +%Y-%m-%d).backup

export PGPASSWORD="$PASSWORD"
COUNTTEMPUSER=$(psql -P format=wrapped  -T -X -A -U ${USERNAME} -p 5490 -h 127.0.0.1 -d ${DATABASE} -c 'SELECT COUNT(*) FROM users')
unset PGPASSWORD

if [[ "$COUNTUSER" == "$COUNTTEMPUSER" ]]
then
  curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":sunny: Backup : $(date +%Y-%m-%d) sama\",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS
else
  curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":thunder_cloud_and_rain: Backup : $(date +%Y-%m-%d) tidak sama\",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS
fi

curl -s -X POST --data-urlencode "payload={\"channel\":\"#backup\",\"username\":\"Bot Q\",\"attachments\":[{\"text\":\":sunny: Cleanup Temp Container\",\"color\":\"good\",\"fields\":[{\"title\":\"master\",\"value\":\"Postgresql Master\"}]}]}" $HOOKS
docker stop $CONTAINER
docker rm $CONTAINER