#!/bin/bash
#
# PostgreSQL Backup Script; based on https://wiki.postgresql.org/wiki/Automated_Backup_on_Linux
# Adding to crontab at every 1:30AM
# $ echo "30 1 * * * /home/xxx/pgbackup.sh" | crontab -

# DB username, default is postgres (if leave empty)
USERNAME=
# Password
# Please create a password file named `.pgpass` and put it in your $HOME directory
# with following format: hostname:port:database:username:password
# ex: localhost:*:*:postgres:postgres
#
# DB hostname
HOSTNAME=localhost
# Backup directory, should be writeable by current running user
BACKUP_DIR=/data/backup/postgresql/
# Which day to take the weekly backup from (1-7 = Monday-Sunday)
DAY_OF_WEEK_TO_KEEP=1
# Which day to take the monthly backup (1-28)
DAY_OF_MONTH_TO_KEEP=1
# Number of days to keep daily backups
DAYS_TO_KEEP=20
# Number of months to keep monthly backups
MONTHS_TO_KEEP=3
# How many weeks to keep weekly backups
WEEKS_TO_KEEP=12

# Email Address to send mail to?
# @TODO
MAIL_ADDR=""

if [ ! $USERNAME ]; then
	USERNAME="postgres"
fi;

function perform_backups()
{
	SUFFIX=$1
	DATE=`date +%Y-%m-%d`
	FINAL_BACKUP_DIR=$BACKUP_DIR"/$SUFFIX/"
 
	if ! mkdir -p $FINAL_BACKUP_DIR; then
		echo "Cannot create backup directory in $FINAL_BACKUP_DIR!" 1>&2
		exit 1;
	fi;
 
	FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn and datname not in ('template0', 'template1', 'postgres');"
 
	echo -e "\n\nPerforming full backups"
	echo -e "--------------------------------------------\n"
 
	for DATABASE in `psql -h "$HOSTNAME" -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY"`
	do
		echo "Plain backup of $DATABASE"

		if ! pg_dump -Fp -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" | gzip > $FINAL_BACKUP_DIR"$DATABASE"."$DATE".sql.gz.in_progress; then
			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
			exit 1;
		else
			mv $FINAL_BACKUP_DIR"$DATABASE"."$DATE".sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE"."$DATE".sql.gz
			# Create a symlink to daily folder
			if [ "$SUFFIX" != "daily" ]
                        then
                                ln -s ../$SUFFIX/"$DATABASE"."$DATE".sql.gz $BACKUP_DIR"daily/"
                        fi
		fi
	done
 
	echo -e "\nAll database backups complete!"

}

# MONTHLY BACKUPS
 
DAY_OF_MONTH=`date +%d`
EXPIRED_DAYS=`expr $(($MONTHS_TO_KEEP * 30))`
 
if [ $DAY_OF_MONTH -eq $DAY_OF_MONTH_TO_KEEP ];
then
	# Delete all expired monthly directories
	find $BACKUP_DIR"monthly" -maxdepth 1 -mtime +$EXPIRED_DAYS -exec rm -rf '{}' ';'
 
	perform_backups "monthly"
 
	exit 0;
fi
 
# WEEKLY BACKUPS
 
DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)
EXPIRED_DAYS=`expr $((($WEEKS_TO_KEEP * 7) + 1))`
 
if [ $DAY_OF_WEEK = $DAY_OF_WEEK_TO_KEEP ];
then
	# Delete all expired weekly directories
	find $BACKUP_DIR"weekly" -maxdepth 1 -mtime +$EXPIRED_DAYS -exec rm -rf '{}' ';'
 
	perform_backups "weekly"
 
	exit 0;
fi
 
# DAILY BACKUPS
 
# Delete daily backups 7 days old or more
find $BACKUP_DIR"daily" -maxdepth 1 -mtime +$DAYS_TO_KEEP -exec rm -rf '{}' ';'
 
perform_backups "daily"

