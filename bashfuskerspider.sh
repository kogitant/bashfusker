# !/bin/sh

#echo name of script is $0

echo 1 argument should be the starting part of the url to fusker with as the range area
echo 1 argument is $1

echo 2 argument should be the ending part of the url to fusker with as the range area
echo 2 argument is $2

echo 3 argument should be the star of range
echo 3 argument is $3

echo 4 argument should be the end of range
echo 4 argument is $4

echo 5 argument should be the log file name to which we append
echo 5 argument is $5

echo 6 argument should be the expected amount of confirmed urls
echo 6 argument is $6

# echo number of arguments is $#
echo :::::::::::::::::::BEGIN PROCESSING:::::::::::::::::::::::

while true; do
	echo -n "Continue? y/n: "
	read choice
	echo

	case $choice in
     		"y")
		#Ok, do nothing
		break;
     		;;
     		"n")
		exit 1
     		;;
     		*)
     		echo "That is not a valid choice, try y or n."
     		;;
	esac  
done

# wgetted Url which is put together from start, range and end
URL=
URL_START=$1
URL_END=$2

# Which (large) number area to spider
START_RANGE=$3
END_RANGE=$4

# Which file will store the results.
# This file can be later used as input to bashspider.sh
LOG_FILE=$5

# If wget gets a 404, then its stored here
FAILURE=

# When getting 404 and trying to find the start or end of a range, we use this multiple of 2 to add to the start_range
START_RANGE_INCREMENT=1

# This will store the last failed range number. This is the starting point of a rewind operation. 
PREVIOUS_FAILED_POSITION=

# This will store the last working start_range in a forward operation
PREVIOUS_WORKING_POSITION=

# Confirmed start & end are the first & last working numbers of a range of numbers in between
CONFIRMED_START=
CONFIRMED_END=
# Count how many confirmed urls were found
CONFIRMED_AMOUNT=0
EXPECTED_CONFIRMED_AMOUNT=0

# First encounter is a boolean that controls if the working url with start_range is the first in a range 
FIRST_ENCOUNTER=1

# This stores all tested positions, which failed. This is output in the end of the file after going throught the whole range
FAILED_POSITIONS=

# This stores the count of how many times the tested url has failed in row
FAIL_COUNT=0

# Wget temporary log file
WGET_LOG_FILE=wget.log

if [ "$6" != "" ]
then
	echo "Setting expected_confirmed_amount to $6"
	EXPECTED_CONFIRMED_AMOUNT=$6
fi

echo Finding correct ranges for fuskerable url:
echo $URL_START ?? $URL_END
echo Search range is from $START_RANGE to $END_RANGE
echo Logging results to file $LOG_FILE
echo "URL_START: $URL_START" >> "$LOG_FILE"
echo "URL_END: $URL_END" >> "$LOG_FILE"
echo "RANGE_START: $START_RANGE" >> "$LOG_FILE"
echo "RANGE_END: $END_RANGE" >> "$LOG_FILE"

while [ $((START_RANGE)) -le $((END_RANGE)) ]
do
	URL=$URL_START$START_RANGE$URL_END
	echo Url: $URL

	wget -o $WGET_LOG_FILE -nd  --spider --accept=jpg $URL
	RESULT=$(cat wget.log | grep "ERROR 404")
	FAILURE=$RESULT
	echo Failure?: $FAILURE

	# If failure, then the url responded with 404
	if [ -n "$FAILURE" ]
	then
		echo "The url failed"
		#The url responded with 404. This means that if we have gotten correct responses before, we need to
		#Log the start & end ranges and reset them for finding the next responding url range

		#Log start & end and reset them & proceed
		if [ -n "$CONFIRMED_START" ]
		then
			echo "We have a confirmed start range: $CONFIRMED_START."
			# We have a CONFIRMED_START and now we have a CONFIRMED_END
			if [ "$START_RANGE_INCREMENT" -gt "1" ]
			then
				echo "Start range increment is -gt 1. Were going to rewind start_range from $START_RANGE. to previous working position: $PREVIOUS_WORKING_POSITION. and reset start range increment to 1"
				# This means that we have been jumping around.
				# We need to rewind back to the previous working position
				START_RANGE=$PREVIOUS_WORKING_POSITION
				START_RANGE_INCREMENT=1
			else
				CONFIRMED_END=$(($START_RANGE-1))
				echo "Confirmed end is thus: $CONFIRMED_END"
				
				#Write to file
				echo "Writing confirmed start & end to file"
				echo "CONFIRMED_START: $CONFIRMED_START" >> "$LOG_FILE"			
				echo "CONFIRMED_END: $CONFIRMED_END" >> "$LOG_FILE"			

				# Count how many confirmed urls have been found thus far
				CONFIRMED_AMOUNT=$((CONFIRMED_AMOUNT+CONFIRMED_END-CONFIRMED_START+1))
				echo "Confirmed amount is now: $CONFIRMED_AMOUNT."
				if [ "$EXPECTED_CONFIRMED_AMOUNT" -gt 0 ]
				then
					if [ "$CONFIRMED_AMOUNT" -ge "$EXPECTED_CONFIRMED_AMOUNT" ]
					then
						echo "Confirmed amount=$CONFIRMED_AMOUNT. and it is greater than or equal to expected confirmed amount=$EXPECTED_CONFIRMED_AMOUNT."
						START_RANGE=$((END_RANGE+1)) 
					elif [ "$CONFIRMED_AMOUNT" -lt "$EXPECTED_CONFIRMED_AMOUNT" ]
					then
						echo "Confirmed amount=$CONFIRMED_AMOUNT. is less than expected confirmed amount=$EXPECTED_CONFIRMED_AMOUNT."
					fi
				fi	
	
				echo "Resetting confirmed start & end"
				#Reset
				CONFIRMED_START=
				CONFIRMED_END=
				if [ "$FIRST_ENCOUNTER" -lt "1" ]
				then
					# Only output this message when there has been a previous first encounter.
					# Probably we could also only reset the variable then, but anyhoo...
					echo "Resetting the first_encounter from $FIRST_ENCOUNTER. to 1"
					# Reset the first_encounter boolean so that when teh next working range is found, we correctly log it
					FIRST_ENCOUNTER=1
				fi
			fi
		else	
			echo "We dont have a confirmed start range: $CONFIRMED_START."

			# This means that we havent got any results yet
			echo "Nothing found yet..."
			FAILED_POSITIONS="$FAILED_POSITIONS $START_RANGE"

			echo "Previous failing position is changed from $PREVIOUS_FAILED_POSITION. to current start range: $START_RANGE."
			# Store this previous failed start_range
			PREVIOUS_FAILED_POSITION=$START_RANGE
			# Increas the increment by n so that the finding of a working start range is faster
			START_RANGE_INCREMENT=$(($START_RANGE_INCREMENT+3))
		fi	

	else
		echo "The url didnt fail"
		# The url is correct (no 404). We need to mark up the first START_RANGE that works
		# so that when the first 404 is gotten, this start_range is written to log. Otherwise we dont do anything.
		if [ "$FIRST_ENCOUNTER" -gt "0" ]
		then
			if [ "$START_RANGE_INCREMENT" -gt "1" ]
			then
				echo "Start range increment is -gt 1. Were going to rewind start_range from $START_RANGE. to previous failing position: $PREVIOUS_FAILED_POSITION. and reset start range increment to 1"
				# This means that we have been jumping around.
				# We need to rewind back to the previous working position
				START_RANGE=$PREVIOUS_FAILED_POSITION
				START_RANGE_INCREMENT=1
			else
				echo "This is the first encounter of a working start_range"
				echo "Setting boolean first_encounter as false"
				FIRST_ENCOUNTER=0
				CONFIRMED_START=$START_RANGE
				echo "Confirmed start range is: $CONFIRMED_START"
			fi
		else
			# We have a CONFIRMED_START and now we have a CONFIRMED_END
			CONFIRMED_END=$(($START_RANGE))
			echo "We have a confirmed start range: $CONFIRMED_START. and a confirmed end range: $CONFIRMED_END."
			# Multiply the increment by two so that the finding of a working end is faster
			START_RANGE_INCREMENT=$(($START_RANGE_INCREMENT+2))
		fi
		echo "Previous working position is changed from $PREVIOUS_WORKING_POSITION. to current start range: $START_RANGE."
		# Store this as previous working start_range
		PREVIOUS_WORKING_POSITION=$START_RANGE
	fi
	echo "Incrementing start range from $START_RANGE by $START_RANGE_INCREMENT"
	TEST=$((START_RANGE+START_RANGE_INCREMENT))
	if [ "$TEST" -gt $END_RANGE ]
	then
		echo "Start range with current increment of $START_RANGE_INCREMENT. would result in exceeding the end range. Resetting increment to 1."
		START_RANGE_INCREMENT=1
	fi
	if [ "$START_RANGE_INCREMENT" -gt "50" ]
	then
		# We don't want to hop over a short range of pictures so we reset the increment to 1
		START_RANGE_INCREMENT=1
	fi
	START_RANGE=$((START_RANGE+START_RANGE_INCREMENT))
done

echo "Script reached its end"

# The last working range is logged here
if [ -n "$CONFIRMED_START" ]
then
	echo "We have a confirmed start range"
	if [ -n "$CONFIRMED_END" ]
	then
		echo "We have also a confirmed end range."
		echo "Writing to log"
        	echo "CONFIRMED_START: $CONFIRMED_START" >> "$LOG_FILE"
        	echo "CONFIRMED_END: $CONFIRMED_END" >> "$LOG_FILE"
	else
		echo "Because we dont have a confirmed end range, the confirmed start range wasnt logged"		
	fi
else
	echo "We dont have even a confirmed start range... It could be that we dound one range & ended without another range"
fi
# This should be enabled by an option
# echo "FAILED: $FAILED_POSITIONS" >> "$LOG_FILE"

# Total confirmed and expected amounts:
echo "CONFIRMED_AMOUNT: $CONFIRMED_AMOUNT" >> "$LOG_FILE"
echo "EXPECTED_CONFIRMED_AMOUNT: $EXPECTED_CONFIRMED_AMOUNT" >> "$LOG_FILE"

# Remove the tremporary wget log file
echo $(rm -f $WGET_LOG_FILE)
