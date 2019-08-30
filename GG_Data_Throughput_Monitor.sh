#!/bin/sh
#Title: Data_Throughput_Monitor_For_GG_in_DIPC_Agent

#
#Statics parameters:
#goldengate home path
gghome="/u01/Middleware/OGG_Target"
#file to keep the replicate record from last time
gg_pre_info="gg_pre_info.txt"
#final report file
gg_report="gg_throughput_report.txt"

#Obtain the current status of all replicats
CUR_INFO=`$gghome/ggsci << EOF
dblogin userid XXXXX   password XXXXX
info replicat *
exit
EOF`

#Obtain the current timestamp
CUR_TIME=$(date)

#main function to check and calculate the throughput
function status {
#extract the replicat name and current RBA position:
LIST=$(echo "$CUR_INFO" | grep -E "REPLICAT|RBA" | sed 's/REPLICAT *//' | sed 's/ *Last.*//' | sed 's/^ *//' | sed 's/^.*RBA //' | awk 'NR%2{printf "%s ",$0;next;}1')
#echo $LIST

#record the RBA difference
SUM=0

for line in  "$LIST"
	do
	set -- $(echo $line | awk '{print $1; print $2}')
	GNAME=$1
	CUR_RBA=$2
        
        #check if a replicat process has been recorded before  
	if [[ $(grep $GNAME gg_pre_info)  ]]   
		then
                #for old replicat process, find its previous RBA position in the record file 
		PRE_RBA=$(grep -n $GNAME gg_pre_info | awk '{print $2}')
		echo $GNAME $CUR_RBA $PRE_RBA
		DIFF=$((CUR_RBA - PRE_RBA))
		if (($DIFF > 0))
			then 
			((SUM+=$CUR_RBA - $PRE_RBA))
		fi
	else
		#for new replicat process, find its start RBA position in GGSCI
		DETAIL_INFO=`$gghome/ggsci << EOF
		dblogin userid XXXXX   password XXXXX
		info replicat $GNAME, showch
		exit
		EOF`
		
		START_RBA=$(echo $(echo "$DETAIL_INFO"| grep -E "Startup Checkpoint|RBA" | sed -n '/Startup Checkpoint/, $p'|sed -n '/RBA/, $p' |sed 's/RBA: *//' ) | awk '{print $1;}') 
		echo $GNAME $CUR_RBA $START_RBA
		((SUM+=$CUR_RBA - $START_RBA))
	fi
done

#echo $SUM
#echo $CUR_TIME
#echo $PRE_TIME

#calculate the time difference bewteen current and previous status-check  in seconds
SEC=`date -ud@$(($(date -ud"$CUR_TIME" +%s)-$(date -ud"$PRE_TIME" +%s))) +%s`
#convert time difference in hh:mm:ss format
TIME=`date +%H:%M:%S -ud @${SEC}`
#echo $TIME

#echo $SEC
#make sure time-interval value is not zero
if (($SEC < 1))
then SEC=1
fi
mb_min=`echo $SUM $SEC | awk '{rv=$1*60/1024/1024/$2; printf("%.2f", rv)}'`
mb_hr=`echo $SUM $SEC | awk '{rv=$1*60*60/1024/1024/$2; printf("%.2f", rv)}'`
gb_hr=`echo $SUM $SEC | awk '{rv=$1*60*60/1024/1024/1024/$2; printf("%.2f", rv)}'`
gb_day=`echo $SUM $SEC | awk '{rv=$1*60*60*24/1024/1024/1024/$2; printf("%.2f", rv)}'`

#print out the current data throughput information
echo  Begin:$PRE_TIME -- End:$CUR_TIME -- Duration:$TIME $'\n'Data Throughput -- mb_min:$mb_min   mb_hr:$mb_hr   gb_hr:$gb_hr  gb_day:$gb_day $'\n'Replicat  Current_RBA$'\n'$LIST $'\n\n'   >> gg_report

}

#main function to check if the "pre-record" file is empty, 
#if so, consider this as the first time run, output the current replicat info into the record file.
#if not, then use its record info to run status() function, at the end, update the record file(only keep the most recent)
function check {
if [[ -s gg_pre_info ]] 
then
PRE_TIME=$(head -n 1 gg_pre_info)  
status
echo -n "" >  gg_pre_info
fi
echo "$CUR_TIME" >> gg_pre_info
echo $LIST >> gg_pre_info 

}

check
