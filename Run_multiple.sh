#!/bin/bash


##### August 2007 Event

#cd DATA
#cp US_CMT/CMTSOLUTION_20070815 .
#mv CMTSOLUTION_20070815 CMTSOLUTION
#cp Stns/STATIONS_2007 .
#mv STATIONS_2007 STATIONS
#cd ..

#echo "Moved files, beginning run"

#./run1_global.bash

#sleep 5h

#i=0
#while [ $i -lt 1 ]; do
#     if [ -e OUTPUT_FILES/timestamp_forward025500 ]; then
#	i=$[$i+1]
#	echo "First run finished; on to next event"
#     else
#	echo "Still waiting"
#	sleep 1h
#     fi
#done

#echo "Done with while loop"
#mv OUTPUT_FILES/*.sem.sac OUTPUT_20070815
#mv OUTPUT_FILES/values_from_mesher.h OUTPUT_20070815
#rm OUTPUT_FILES/*

###
##### January 2010 Event
###

cd DATA
cp US_CMT/CMTSOLUTION_20100110 .
mv CMTSOLUTION_20100110 CMTSOLUTION
cp Stns/STATIONS_2010 .
mv STATIONS_2010 STATIONS
cd ..

echo "Moved files, beginning run"

./run1_global.bash

sleep 5h

i=0
while [ $i -lt 1 ]; do
     if [ -e OUTPUT_FILES/timestamp_forward025400 ]; then
        i=$[$i+1]
        echo "Second run finished; on to next event"
     else
        echo "Still waiting"
	sleep 1h
     fi
done

mv OUTPUT_FILES/*.sem.sac OUTPUT_20100110
mv OUTPUT_FILES/values_from_mesher.h OUTPUT_20100110
rm OUTPUT_FILES/*



###
##### April 2010 Event
###

cd DATA
cp US_CMT/CMTSOLUTION_20100404 .
mv CMTSOLUTION_20100404 CMTSOLUTION
cp Stns/STATIONS_2010 .
mv STATIONS_2010 STATIONS
cd ..

echo "Moved files, beginning run"

./run1_global.bash

sleep 5h

i=0
while [ $i -lt 1 ]; do
     if [ -e OUTPUT_FILES/timestamp_forward025500 ]; then
        i=$[$i+1]
        echo "Third run finished; on to next event"
     else
        echo "Still waiting"
        sleep 1h
     fi
done

mv OUTPUT_FILES/*.sem.sac OUTPUT_20100404
mv OUTPUT_FILES/values_from_mesher.h OUTPUT_20100404
rm OUTPUT_FILES/*


###
##### May 2013 Event
###

cd DATA
cp US_CMT/CMTSOLUTION_20130524 .
mv CMTSOLUTION_20130524 CMTSOLUTION
cp Stns/STATIONS_2013 .
mv STATIONS_2013 STATIONS
cd ..

echo "Moved files, beginning run"

./run1_global.bash

sleep 5h

i=0
# Go to 027100 for AK135; 025800 for PREM
while [ $i -lt 1 ]; do
     if [ -e OUTPUT_FILES/timestamp_forward027100 ]; then
        i=$[$i+1]
        echo "Fourth run finished; done with all events"
     else
        echo "Still waiting"
        sleep 1h
     fi
done

mv OUTPUT_FILES/*.sem.sac OUTPUT_20130524
mv OUTPUT_FILES/values_from_mesher.h OUTPUT_20130524
rm OUTPUT_FILES/*

