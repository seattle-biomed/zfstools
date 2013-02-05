#!/usr/bin/env bash

function banner {
    echo "Usage:"
    echo "  $0 -h"
    echo "  $0 -d <filesystem> -e <earlier snap> -l <later snap> -o <outdir>"
    exit 1
}

while getopts d:e:l:o: option; do
    case "${option}" in
	d) filesystem=${OPTARG} ;;
	e) snap1=${OPTARG} ;;
	l) snap2=${OPTARG} ;;
	o) outdir=${OPTARG} ;;
	*) banner ;;
    esac
done

if [ -z "$filesystem" ] ; then
    echo "Filesystem is a required argument."
    echo
    banner
fi

if [ -z "$snap1" ] ; then
    echo "Earlier snapshot is a required argument."
    echo
    banner
fi

if [ -z "$snap2" ] ; then
    echo "Later snapshot is a required argument."
    echo
    banner
fi

if [ -z "$outdir" ] ; then
    echo "Output directory is a required argument."
    echo
    banner
fi

if [ ! -d $outdir ] ; then
    echo "Output directory does not exist or is not a directory."
    echo
    banner
fi

date=/bin/date
zfs=/sbin/zfs

outfile=${outdir}/$(/bin/date '+%Y-%m-%d-%H:%M:%S-daily.difflog')

$zfs diff ${filesystem}@${snap1} ${filesystem}@${snap2} > $outfile
