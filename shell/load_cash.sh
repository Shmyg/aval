#!/bin/bash

# Script for loading cash from UMC shops into Oracle table
# Loads calls by means of SQL*Loader
# Created by Shmyg
# LMD by Shmyg 19.11.2003

#. ${HOME}/.bash_profile


DATA_DIR=/home/shmyg/TMP/payment_files

# Startup checks
# Checking that DB access vars set
if [ -z "$DB_USER" -o -z "$DB_NAME" -o -z "$DB_PASS" ] ; then
 echo "Cannot access database - DB_USER/DB_NAME/DB_PATH not set"
 exit
fi

# Checking working environment
if [ -z "$LOG_DIR" -o -z "$WORK_DIR" ] ; then
 echo "LOG_DIR or WORK_DIR is not set"
 exit
fi

# Looking for files and try to load them into the database
# We need to filter out already processed files
cd $DATA_DIR
 for FILE_NAME in `find . -type f -a ! -name "*.proc" -a ! -name "payments.fifo"`; do
  DIR_NAME=`dirname ${FILE_NAME#*/}`
  echo $DIR_NAME
  DATA_FILE=`basename ${FILE_NAME#*/}`
  CONTROL_FILE=$WORK_DIR/aval/control_files/$DIR_NAME/cash.ctl

  # Checking if control file exists
  # Directory structure for control files must be the same as for data files
  if [ ! -r "$CONTROL_FILE" ]; then
   echo "Control file $CONTROL_FILE doesn't exist or is not readable - skipping directory"
  else
   # Adding filename to each row in datafile through fifo
   cat $FILE_NAME | sed -e "s/$/$DATA_FILE/" > payments.fifo &
   # Invoking SQL*Loader
   echo $DB_PASS | \
           sqlldr control=$WORK_DIR/aval/control_files/$DIR_NAME/cash.ctl \
	   data=payments.fifo \
	   log=$LOG_DIR/$DIR_NAME/$DATA_FILE.log \
	   bad=$LOG_DIR/$DIR_NAME/$DATA_FILE.bad \
	   discard=$LOG_DIR/$DIR_NAME/$DATA_FILE.disc \
	   userid=$DB_USER@$DB_NAME

   RET_CODE=$?

   # Checking return code
   # 2 - it's warning - maybe some bad records found
   if [ "$RET_CODE" -eq "0" -o "$RET_CODE" -eq "2" ]; then
    # Checking if there is discards file
    test -f $LOG_DIR/$FILE_NAME.disc && rm -f $LOG_DIR/$FILE_NAME.disc
    # mv $FILE_NAME $FILE_NAME.proc
   else
    echo "SQL*Loader returned with code $RET_CODE. Something might be wrong - you'd better check"
   fi  
  fi
 done