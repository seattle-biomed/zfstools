#!/usr/local/bin/bash

function banner {
    echo "Usage:"
    echo "  $0 -h"
    echo "  $0 -s SECONDARY -p POOL1 -d POOL2 -n SNAP [ -x EXCLUDE ]"
    echo "    SECONDARY - secondary hostname"
    echo "    POOL1 - source zpool"
    echo "    POOL2 - destination zpool"
    echo "    SNAP - snapshot base name"
    echo "    EXCLUDE - space-delimited list of file systems not to replicate"
    exit 1
}

while getopts s:p:d:n:x: option; do
    case "${option}" in
	s) SECONDARY=${OPTARG} ;;
	p) POOL1=${OPTARG} ;;
	d) POOL2=${OPTARG} ;;
	n) SNAP=${OPTARG} ;;
	x) EXCLUDE=${OPTARG} ;;
	*) banner ;;
    esac
done

if [ -z "$SECONDARY" ] ; then
    echo "Must enter a destination host"
    echo
    banner
fi

if [ -z "$POOL1" ] ; then
    echo "Must enter a source zpool"
    echo
    banner
fi

if [ -z "$POOL2" ] ; then
    echo "Must enter a destination zpool"
    echo
    banner
fi

if [ -z "$SNAP" ] ; then
    echo "Must enter a snapshot name"
    echo
    banner
fi

# FreeBSD binary locations, adjust for Solaris/Nexenta/whatever:
AWK='/usr/bin/awk'
DATE='/bin/date'
GREP='/usr/bin/grep'
MBUFFER='/usr/local/bin/mbuffer'
SED='/usr/local/bin/gsed' # Must be GNU sed!
SSH='/usr/bin/ssh'
ZFS='/sbin/zfs'

# Gather volumes on source system.  We're interested in the *volumes*
# but not the *pool* - therefore look for a forward slash:
volumes=`$ZFS list -H -r $POOL1 | $AWK '{ print $1 }' | $GREP '/'`

if [ -n "$EXCLUDE" ] ; then
    for x in $EXCLUDE; do
	volumes=`echo $volumes | $SED "s%\b$x[^\w/]%%g"`
	volumes=`echo $volumes | $SED "s%\b$x$%%g"`
    done
fi

# Send incremental snapshot per-volume:
for v in $volumes; do

    # Check return code of zfs list to see whether we need to do an initial 
    # sync, or an incremental:
    $SSH $SECONDARY $ZFS list $v > /dev/null 2>&1

    if [ "$?" -ne "0" ]; then
	# initial transfer:
	$ZFS send ${v}@${SNAP}.0 | $SSH -c arcfour128 $SECONDARY "${MBUFFER} -q -s 128k -m 1G | $ZFS recv -d $POOL2"
    else
	# incremental transfer:
	$ZFS send -i @${SNAP}.1 ${v}@${SNAP}.0 | $SSH -c arcfour128 $SECONDARY "${MBUFFER} -q -s 128k -m 1G | $ZFS recv -F -d $POOL2"
    fi
done
