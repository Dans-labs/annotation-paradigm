#!/bin/sh

workdir1="/Users/dirk/Data/DANS/demos/apps/pa/data/TommyWasserman/Transkriptioner_kopior"
workdir2="/Users/dirk/Data/DANS/demos/apps/pa/data/TommyWasserman/Transkriptioner_kopior/oönskade"


for workdir in $workdir1 $workdir2
do
	cd $workdir
	for file in * 
	do
		if 
			[ -f $file ]
		then
			mv $file $file.txt
		fi
	done
done

exit

