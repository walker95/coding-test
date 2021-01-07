#!/bin/sh
#logrotate for pb2020-1
sep="============================================================================="
analyticLog=~/cronLogs/facebook/facebookAnalytics
analyticsCorrectionLog=~/cronLogs/facebook/facebookAgeAnalyticsCorrection
ageAnalyticsLog=~/cronLogs/facebook/facebookAgeAnalytics
ageAnalyticsCorrectionLog=~/cronLogs/facebook/facebookAgeAnalyticsCorrection

ganalyticsLog=~/cronLogs/google/googleAnalytics
ganalyticsAgeLog=~/cronLogs/google/googleAnalyticsAge
ganalyticsCorrectionLog=~/cronLogs/google/googleAnalyticsCorrection
ganalyticsGenderLog=~/cronLogs/google/googleAnalyticsGender

tanalyticsLog=~/cronLogs/twitter/twitterAnalytics
tcorrectionLog=~/cronLogs/twitter/twitterCorrection

compress(){
	echo "chnaging directory $dir"
	cd $dir && logFile=$(basename $dir)Logs_$(date --date='yesterday' +'%d%b%Y')
	if [ -e "${logFile}.log" ]
	then
		echo "File ${logFile}.log exists. compressing."
		tar -czf "${logFile}.tgz" "${logFile}.log" && echo "compression Done. deleting log file..." && echo "${logFile}.log will be deleted..." && cd ~ || echo "compression failed. Trye again...."
	else
		echo "File ${file} dosen't exists. exiting"
		cd ~
	fi
}

rotateLog(){
	for dir in $@
	do
		echo $sep
		compress $dir
		echo $sep
	done
}
rotateLog $analyticLog $analyticsCorrectionLog $ageAnalyticsLog $ageAnalyticsCorrectionLog $ganalyticsLog $ganalyticsAgeLog $ganalyticsCorrectionLog $ganalyticsGenderLog $tanalyticsLog $tcorrectionLog
















