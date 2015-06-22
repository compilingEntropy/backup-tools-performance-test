#!/bin/bash

# Author: Aurelio Santos - aurhes@gmail.com
# Modified by: compilingEntropy - compilingEntropy@gmail.com
# 
# HashBackup build #1330
# rdiff-backup 1.2.8
# obnam 1.9
# Attic 0.16
# Borg 0.23.0
#
# Usage:
#     ./backup_tools_test.sh N    - Execute only one test. N indicates the number of the test
#     ./backup_tools_test.sh      - Execute all tests
#
# Client requirements: ssh, openssl, dstat, rsync, rdiff-backup, rsyncrypto, gnupg, obnam, hashbackup, attic, borg
#
# Tests:
#                 compress encrypt
# rsync        0
# rsync        1      x
# rdiff-b.     2
# rdiff-b.     3      x
# rdiff-b.     4      x       x
# obnam        5
# obnam        6      x
# obnam        7      x       x
# hashbackup   8      x       x
# attic        9      x
# attic        10     x       x
# borg         11     x
# borg         12     x       x
#
# Test groups: [0,2,5],[1,3,6,9,11],[4,7,8,10,12]

PWD="$(pwd)"

SOURCE="source"
DESTINATION="backup"
TMP="<tmp>"
#HOST="<server_ip>"
#USER="<username>"
LOG_FILE="log"`date +%Y%m%d%H%M%S`".txt"

FILE_SIZE=215
NUM_FILES=50000
MAX_SUB_DIRS=10
MAX_LEVELS_SUB_DIRS=10

# rsync
b[0]="rsync -a $SOURCE $DESTINATION/"
r[0]="rsync -a $DESTINATION/ $SOURCE"

b[1]="rsync -az $SOURCE $DESTINATION/"
r[1]="rsync -az $DESTINATION/ $SOURCE"

# rdiff-backup
b[2]="rdiff-backup --no-compression $SOURCE $DESTINATION/"
r[2]="rdiff-backup -r now --no-compression $DESTINATION/ $SOURCE"

b3()
{
	mkdir -p $TMP/
	rsync -Paq -f"+ */" -f"- *" $SOURCE/ $TMP/
	cd $SOURCE
	find ./ -type f -print0 | parallel -0 -I{} "gzip -c -6 --rsyncable {} > $TMP/{}"

	rdiff-backup --no-compression $TMP/ $DESTINATION/
	rm -rf $TMP/
	cd $PWD
}

r3()
{
	mkdir -p $TMP/
	rdiff-backup --no-compression -r now $DESTINATION/ $TMP/

	rsync -Paq -f"+ */" -f"- *" $TMP/ $SOURCE/
	cd $TMP/
	find ./ -type f -print0 | parallel -0 -I{} "zcat {} > $SOURCE/{}"
	rm -rf $TMP/
	cd $PWD
}

b[3]="b3"
r[3]="r3"

PUBKEY="<public-key>"
b4()
{
	mkdir -p $TMP/2/
	rsyncrypto -r $SOURCE $TMP/2/ $TMP/1/ $PUBKEY -b 256

	rdiff-backup --no-compression $TMP/2/ $DESTINATION/
	rm -rf $TMP/
}

PRIVKEY="<private-key>"
r4()
{
	mkdir -p $TMP/2/
	rdiff-backup -r now --no-compression $DESTINATION/ $TMP/2/
	
	rsyncrypto -rd $TMP/2/ $SOURCE $TMP/1/ $PRIVKEY
	rm -rf $TMP/
}

b[4]="b4"
r[4]="r4"

# obnam
b[5]="obnam backup --repository $DESTINATION/ $SOURCE"
r[5]="obnam restore --repository $DESTINATION/ --to $SOURCE"

b[6]="obnam backup --compress-with=deflate --repository $DESTINATION/ $SOURCE"
r[6]="obnam restore --repository $DESTINATION/ --to $SOURCE"

GPGFINGERPRINT="<fingerprint>"
b[7]="obnam backup --compress-with=deflate --encrypt-with=$GPGFINGERPRINT --repository $DESTINATION/ $SOURCE"
r[7]="obnam restore --repository $DESTINATION/ --to $SOURCE"

# hashbackup
b[8]="hb init -c $DESTINATION/; hb backup -c $DESTINATION/ -D 400m -Z 6 $SOURCE"
r[8]="cd $SOURCE; hb get -c $DESTINATION/ /; cd $PWD"

# attic
export ATTIC_PASSPHRASE="<passphrase>"
i=1
b[9]="attic init $DESTINATION/attic; attic create -s $DESTINATION/attic::$((i++)) $SOURCE"
r[9]="cd $SOURCE; attic extract $DESTINATION/attic::$((i-1)); cd $PWD"

i=1
b[10]="attic init -e passphrase $DESTINATION/attic; attic create -s $DESTINATION/attic::$((i++)) $SOURCE"
r[10]="cd $SOURCE; attic extract $DESTINATION/attic::$((i-1)); cd $PWD"

# borg
i=1
b[11]="borg init $DESTINATION/borg; borg create -s $DESTINATION/borg::$((i++)) $SOURCE"
r[11]="cd $SOURCE; borg extract $DESTINATION/borg::$((i-1)); cd $PWD"

export BORG_PASSPHRASE="<passphrase>"
i=1
b[12]="borg init -e passphrase $DESTINATION/borg; borg create -s $DESTINATION/borg::$((i++)) $SOURCE"
r[12]="cd $SOURCE; borg extract $DESTINATION/borg::$((i-1)); cd $PWD"

#######################################################################

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
	rm -r $DESTINATION; mkdir $DESTINATION

	# full backup
	echo Backup $i: ${b[$i]}
	echo Backup $i: ${b[$i]} >> $LOG_FILE

	sync
	dstat -Tcmnd --output "dstat"$i"_b.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${b[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Space: $(du -s "$DESTINATION" | cut -f1) >> $LOG_FILE

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

	sync
	dstat -Tcmnd --output "dstat"$i"_i.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${b[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Space: $(du -s "$DESTINATION" | cut -f1) >> $LOG_FILE

	rm -r $SOURCE

	# restore operation
	echo Restore $i: ${r[$i]}
	echo Restore $i: ${r[$i]} >> $LOG_FILE

	sync
	dstat -Tcmnd --output "dstat"$i"_r.csv" & PID=$!; sleep 5
	TIME=$(date +%s)

	${r[$i]}

	TIME=$(($(date +%s)-TIME))
	sleep 5; kill $PID

	echo Time: $TIME >> $LOG_FILE
	echo Restored space: $(du -s $SOURCE | cut -f1) >> $LOG_FILE

done
