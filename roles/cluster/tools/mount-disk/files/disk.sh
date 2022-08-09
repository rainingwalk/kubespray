#!/bin/bash

DISK=$1
MOUNTDIR=$2
PORTITION=$3

if echo "$PORTITION" | egrep "/dev/[a-z][a-z][a-z][1-4]"; then
    PORTITION_NUM=${PORTITION: -1}
else
    echo "Error: $PORTITION is invalid, must ended by a number, example: ${DISK}1"; exit 1;
fi

[[ -d ${MOUNTDIR} ]] && { echo "${MOUNTDIR} already mounted"; exit 1;}

CHECK_EXIST=`fdisk -l 2> /dev/null | grep -o "$DISK"`
[[ ! "$CHECK_EXIST" ]] && { echo "Error: $DISK is not found !"; exit 1;}

CHECK_DISK_EXIST=`fdisk -l 2> /dev/null | grep -o "$PORTITION"`
[[ ! "$CHECK_DISK_EXIST" ]] || { echo "WARNING: ${CHECK_DISK_EXIST} is Partitioned already !";}

fdisk $DISK<<EOF
d
n
p
$PORTITION_NUM

t

w
EOF
