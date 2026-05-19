#!/bin/bash

# Create needed user and group
groupadd team

tee /srv/status.sh << EOF
#! /bin/bash
echo -n "status.sh successfully executed by "
whoami
EOF

chmod 0750 /srv/status.sh

tee /srv/tasks.txt << EOF
1. Finish this Permissions Lab
2. Do the Networking Configuration Basics Lab
3. Listen to the latest episode of Into The Terminal
EOF

chmod 0750 /srv/tasks.txt

export CONTRACTDIR=/srv/proprietary

mkdir $CONTRACTDIR
chown $CONTRACTDIR root:root
chmod 0640 $CONTRACTDIR
touch $CONTRACTDIR/contract{01..04}.txt

echo "You should enjoy the subtle detours." > $CONTRACTDIR/contract01.txt
echo "to the fullest," > $CONTRACTDIR/contract02.txt
echo "because that is where you find the things" > $CONTRACTDIR/contract03.txt
echo "that are more important than what you want." > $CONTRACTDIR/contract04.txt
chmod 777 $CONTRACTDIR/*.txt

