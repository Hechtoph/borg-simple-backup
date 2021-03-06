#!/bin/bash
# BorgBackup Simple Backup Script V1.0

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 configfile (located in folder ./config)" >&2
  exit 1
fi

##INPUT
JOBNAME=$1
##INPUT
WORKINGDIRECTORY=$(dirname "$BASH_SOURCE")
CONFIGFILE="$WORKINGDIRECTORY/config/$JOBNAME"
TIMESTAMP="$(date +"%Y-%m-%d-%H-%M-%S")"

#QUIT IF CONFIGFILE DOES NOT EXIST
if [ ! -f $CONFIGFILE ]
then
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):ERROR: Configfile not found, aborting."
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------UNSUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------"
        exit 2
fi

chmod +x $CONFIGFILE
. $CONFIGFILE
export BORG_PASSPHRASE=$BORG_PASSPHRASE

HOST=$(hostname)

#Dateien
TIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/$JOBNAME"
LOCKFILE="$WORKINGDIRECTORY/locks/$JOBNAME"
LOGFILE="$WORKINGDIRECTORY/logs/$JOBNAME-$TIMESTAMP"


#Create folder structure
DIRTIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/"
DIRLOCKFILE="$WORKINGDIRECTORY/locks/"
DIRLOGFILE="$WORKINGDIRECTORY/logs/"
mkdir -p $DIRTIMESTAMPFILE $DIRLOCKFILE $DIRLOGFILE

#Logfile erstellen
touch $LOGFILE

echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------STARTING BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------" | tee -a $LOGFILE

##QUIT IF LOCKFILE EXISTS
if [ -f $LOCKFILE ]
then
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):ERROR: Lockfile found, aborting." | tee -a $LOGFILE
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------UNSUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------" | tee -a $LOGFILE
        sendemail -f $MAILFROM -t $MAILTO -u "ERROR: BORGBACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":(" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=yes -a $LOGFILE
        exit 3
fi

##CREATE LOCKFILE
touch $LOCKFILE

##DO BACKUP
echo "$(date +"%Y-%m-%d-%H-%M-%S"):----RUNNING BACKUP JOB----" | tee -a $LOGFILE
$BORGLOCATION create --info --compression $COMPRESSION --stats -x $REPOSITORY::$JOBNAME-$TIMESTAMP $MOUNTPATH 2>&1 >/dev/null | tee -a $LOGFILE
BORGERRORLEVEL=$PIPESTATUS
if [ $BORGERRORLEVEL -gt 1 ]
then
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):ERROR: Borg returned error $BORGERRORLEVEL, aborting." | tee -a $LOGFILE
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------UNSUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------" | tee -a $LOGFILE
        sendemail -f $MAILFROM -t $MAILTO -u "ERROR: BORGBACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":(" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=yes -a $LOGFILE
        rm $LOCKFILE
        exit 4
fi
echo "$(date +"%Y-%m-%d-%H-%M-%S"):----FINISHED BACKUP JOB WITH RETURN CODE $ERRORLEVEL----" | tee -a $LOGFILE

##PRUNE
echo "$(date +"%Y-%m-%d-%H-%M-%S"):----PRUNING BORG REPO----" | tee -a $LOGFILE
$BORGLOCATION prune --force -s -H $KEEPHOURS -d $KEEPDAYS -w $KEEPWEEKS -m $KEEPMONTHS --keep-last $KEEPLAST -P $JOBNAME $REPOSITORY 2>&1 >/dev/null | tee -a $LOGFILE
echo "$(date +"%Y-%m-%d-%H-%M-%S"):----Finished Pruning Borg Repo----" | tee -a $LOGFILE

##FINISH
if [ $BORGERRORLEVEL -gt 0 ]
then
	echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP WITH WARNINGS----------" | tee -a $LOGFILE
	sendemail -f $MAILFROM -t $MAILTO -u "WARNING: BORGBACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":/" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=yes -a $LOGFILE
fi
if [ $BORGERRORLEVEL -eq 0 ]
then
	echo "$(date +"%Y-%m-%d-%H-%M-%S"):----------SUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP WITHOUT ERROR----------" | tee -a $LOGFILE
	sendemail -f $MAILFROM -t $MAILTO -u "SUCCESS: BORGBACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":)" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=yes -a $LOGFILE
fi
rm $TIMESTAMPFILE
touch $TIMESTAMPFILE
rm $LOCKFILE
exit 0