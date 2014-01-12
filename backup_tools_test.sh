#!/bin/bash

# Author: Aurelio Santos - aurhes@gmail.com
#
# Usage:
#     ./backup_tools_test.sh N    - Execute only one test. N indicates the number of the test
#     ./backup_tools_test.sh      - Execute all tests
#
# Client requirements: ssh, dstat, rsync, rdiff-backup, duplicity, areca and link-backup
# Server requirements: sshd
#
# Tests:
#              compress encrypt
# rsync     0
# rdiff-b.  1
# rdiff-b.  2      x
# duplicity 3      x
# duplicity 4      x       x
# areca     5
# areca     6      x
# areca     7      x       x
# linkb     8
#
# Test groups: [0,1,5,8],[2,3,6],[4,7]

SOURCE="source"
DESTINATION="backup"
HOST="<server_ip>"
USER="<username>"
LOG_FILE="log"`date +%Y%m%d%H%M%S`".txt"

FILE_SIZE=215
NUM_FILES=50000
MAX_SUB_DIRS=10
MAX_LEVELS_SUB_DIRS=10

# rsync
b[0]="rsync -a -e ssh $SOURCE $USER@$HOST:$DESTINATION/"
r[0]="rsync -a -e ssh $USER@$HOST:$DESTINATION/ $SOURCE"

# rdiff-backup
b[1]="rdiff-backup --no-compression $SOURCE $USER@$HOST::$DESTINATION/"
r[1]="rdiff-backup -r now --no-compression $USER@$HOST::$DESTINATION/ $SOURCE"

b[2]="rdiff-backup $SOURCE $USER@$HOST::$DESTINATION/"
r[2]="rdiff-backup -r now $USER@$HOST::$DESTINATION/ $SOURCE"

# duplicity
b[3]="duplicity --no-encryption $SOURCE ssh://$USER@$HOST/$DESTINATION/"
r[3]="duplicity --no-encryption ssh://$USER@$HOST/$DESTINATION/ $SOURCE" 

export PASSPHRASE=""
KEY="<key>"
b[4]="duplicity --encrypt-key $KEY $SOURCE ssh://$USER@$HOST/$DESTINATION/"
r[4]="duplicity --encrypt-key $KEY ssh://$USER@$HOST/$DESTINATION/ $SOURCE"

# areca
ARECA_CONFIG_FILE="<path_to_areca_configuration_file>"
ARECA_CONFIG_FILE_COMPRESSION="<path_to_areca_configuration_file>"
ARECA_CONFIG_FILE_COMPRESSION_ENCRYPTION="<path_to_areca_configuration_file>"

b[5]="areca_cl backup -config $ARECA_CONFIG_FILE"
r[5]="areca_cl recover -destination $SOURCE -config $ARECA_CONFIG_FILE"

b[6]="areca_cl backup -config $ARECA_CONFIG_FILE_COMPRESSION"
r[6]="areca_cl recover -destination $SOURCE -config $ARECA_CONFIG_FILE_COMPRESSION"

b[7]="areca_cl backup -config $ARECA_CONFIG_FILE_COMPRESSION_ENCRYPTION"
r[7]="areca_cl recover -destination $SOURCE -config $ARECA_CONFIG_FILE_COMPRESSION_ENCRYPTION"

# link-backup
b[8]="lb $SOURCE $USER@$HOST:$DESTINATION"
r[8]="lb $USER@$HOST:$DESTINATION $SOURCE"

# remove files that can conflict with the new ones
if [ $# == 1 ]; then
  BEGIN=$1; END=$1;
  rm dstat$1_b.csv dstat$1_i.csv dstat$1_r.csv
else
  BEGIN=0; END=8;
  rm dstat*.csv
fi

# generate the data set
rm -r $SOURCE"_tmp"; mkdir $SOURCE"_tmp";
for (( i=0; i<$NUM_FILES; i++ ))
do
	DIR=$SOURCE"_tmp"
	for (( j=0; j<$[ $RANDOM % $MAX_SUB_DIRS ]; j++ ))
	do
		DIR=$DIR/dir$[ $RANDOM % $MAX_LEVELS_SUB_DIRS ]
	done
	if [ ! -d $DIR ]; then
		mkdir -p $DIR
	fi

	dd if=/dev/urandom of=$DIR/file$i count=1024 bs=$[ $FILE_SIZE / 2 ]
	dd if=/dev/zero count=1024 bs=$[ $FILE_SIZE / 2 ] >> $DIR/file$i
done

for (( i=$BEGIN; i<=$END; i++ ))
do
	rm -r $SOURCE; mkdir $SOURCE
	cp -r $SOURCE"_tmp"/* $SOURCE/
	ssh $HOST "rm -r $DESTINATION; mkdir $DESTINATION"

	# full backup
	echo Backup $i: ${b[$i]}
	echo Backup $i: ${b[$i]} >> $LOG_FILE

	ssh $HOST "sync"
	dstat -Tcmnd --output "dstat"$i"_b.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${b[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Space: $(ssh $HOST "du -s "$DESTINATION" | cut -f1") >> $LOG_FILE

	# modify files
	for (( j=0; j<$NUM_FILES; j=j+10 ))
	do
		FILE1=$(find $SOURCE -name "file"$j )
		FILE2=$(find $SOURCE -name "file"$[ $j + 1 ])
		split -n 2 $FILE1 $FILE1
		rm $FILE1 $FILE1"ab"
		mv $FILE1"aa" $FILE1
		dd if=/dev/urandom count=1024 bs=$[ $FILE_SIZE / 4 ] >> $FILE1
		dd if=/dev/zero count=1024 bs=$[ $FILE_SIZE / 4 ] >> $FILE1

		rm $FILE2

		dd if=/dev/urandom of=$FILE2"_new" count=1024 bs=$[ $FILE_SIZE / 2 ]
		dd if=/dev/zero count=1024 bs=$[ $FILE_SIZE / 2 ] >> $FILE2"_new"
	done

	# incremental backup
	echo Increment $i: ${b[$i]}
	echo Increment $i: ${b[$i]} >> $LOG_FILE

	ssh $HOST "sync"
	dstat -Tcmnd --output "dstat"$i"_i.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${b[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Space: $(ssh $HOST "du -s "$DESTINATION" | cut -f1") >> $LOG_FILE

	rm -r $SOURCE

	# restore operation
	echo Restore $i: ${r[$i]}
	echo Restore $i: ${r[$i]} >> $LOG_FILE

	ssh $HOST "sync"
	dstat -Tcmnd --output "dstat"$i"_r.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${r[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Restored space: $(du -s $SOURCE | cut -f1) >> $LOG_FILE

done
