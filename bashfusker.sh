# !/bin/sh

#
# TODO:
#
# Include an option for verbose & debug output
#	These should use same output function which decides what to show
#
# Include an option to override failure_count
#
# Log stuff to some given logfile if given
#
# Log all downloads somewhere
#
# Rename files like in Fujker! 
# 
# Include possibility to give wget parameters
#
# Wget should not download a file if it exists
# 
# Wget accept values
#
# Failurecount as an option
#
# Increment as an option

#
# Usage: bashfusker -s -e -l -h -f -b
#

#
# help() To print help
#
function help()
{
  echo "Usage: $0 -s -e -l -h [-f]"
  echo "Options:"
  echo " -s Beginning part of the URL to fusker"
  echo " -e Ending part of the URL to fusker"
  echo " -l Lower limit of RANGE"
  echo " -h Higher limit of RANGE"
  echo "Or:"
  echo " -f Filename of a file generated with bashfuskerspider.sh which has all needed values"
  echo "    (if any of the above options are used, this overrides them. "
  echo "Optional in all cases:"
  echo " -b Give the minimum size of files to download"
  exit 1
}

function confirmStartup(){

echo "Either these all should be given..."
echo "s) should be the first part of the url to fusker."
echo ":$URL_START"
echo "e) should be the second(last) part of the url to fusker."
echo ":$URL_END"
echo "l) should be the lower limit of the fuskering range."
echo ":$START_RANGE"
echo "h) should be the upper limit of the fuskering range."
echo ":$END_RANGE"
echo "Or this should be given..."
echo "f) should be the bashfuskerspider generated file with all of the above data (and more)"
echo ":$SPIDERED_INPUT_FILE"
echo "b) Optionally you can also specify the minimum file size for downloading (in bytes)"
echo ":$MINIMUM_FILE_LENGTH"

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
}

#
# processInputFile to process file specified with startup option -f
#
function processInputFile(){
	
	cat $SPIDERED_INPUT_FILE | while read line;
	do
		DOWNLOAD_RANGE_FOUND=0
      		IDENTIFIER=$(echo $line | awk '{print $1}')
        	VALUE=$(echo $line | awk '{print $2}')

		if [ "$IDENTIFIER" == "URL_START:" ]
		then
			echo "Identifier matches URL_START"
			URL_START=$VALUE
		fi
		if [ "$IDENTIFIER" == "URL_END:" ]
		then
			echo "Identifier matches URL_END"
			URL_END=$VALUE
		fi
		if [ "$IDENTIFIER" == "RANGE_START:" ]
		then
			echo "Identifier matches RANGE_START"
		fi
		if [ "$IDENTIFIER" == "RANGE_END:" ]
		then
			echo "Identifier matches RANGE_END"
		fi
		if [ "$IDENTIFIER" == "CONFIRMED_START:" ]
		then
			echo "Identifier matches CONFIRMED_START"
			START_RANGE=$VALUE
		fi
		if [ "$IDENTIFIER" == "CONFIRMED_END:" ]
		then
			echo "Identifier matches CONFIRMED_END"
			END_RANGE=$VALUE
			echo "Setting download_range_found as true"
			DOWNLOAD_RANGE_FOUND=1
		fi
		if [ "$DOWNLOAD_RANGE_FOUND" -eq 1 ]
		then
			echo "Downloading the found range."
			download $URL_START $URL_END $START_RANGE $END_RANGE
			echo "Resetting download_range_found to 0"
			DOWNLOAD_RANGE_FOUND=0
		fi
		
	done
}

#
# download to download from url within given range
#
function download(){
	#Attributes of this function:
	#$1 URL_START
	URL_S=$1
	#$2 URL_END
	URL_E=$2
	#$3 START_RANGE
	URL_RS=$3
	#$4 END_RANGE
	URL_RE=$4

	while [ $((URL_RS)) -le $((URL_RE)) ]
	do

		# should we skip downloading this file?
		# -b argument is related to this
		# reset to 0 before each loop
		SKIP_THIS_FILE=0

		URL=$URL_S$URL_RS$URL_E
		echo $URL
		if [ "$MINIMUM_FILE_LENGTH" -gt 0 ]
		then
			# We need to check the filesize before downloading
			
			wget -nc -o $WGET_LOG_FILE -nd --spider --accept=jpg $URL
			RESULT_LENGTH=$(cat $WGET_LOG_FILE | grep "Length:")
			NO_CLOBBER=$(cat $WGET_LOG_FILE | grep "already there, will not retrieve.")
			if [ "$NO_CLOBBER" == "" ]
			then
      				IDENTIFIER=$(echo $RESULT_LENGTH | awk '{print $1}')
        			VALUE=$(echo $RESULT_LENGTH | awk '{print $2}')
				echo "Value before , replacement: $VALUE."
				VALUE=${VALUE//,/}
        			echo Length awked:$IDENTIFIER=$VALUE
				if [ "$MINIMUM_FILE_LENGTH" -gt "$VALUE" ]
				then
					# The file is too small, skip downloading
					echo "Skipping downloading because file is too small."
					SKIP_THIS_FILE=1
				fi
			else
				echo "File already exists."
			fi
		fi
		if [ "$SKIP_THIS_FILE" -ne 1 ]
		then
			echo $(wget -nc -o $WGET_LOG_FILE -nd  --accept=jpg $URL)
			FAILURE=$(cat $WGET_LOG_FILE | grep "ERROR 404")
			echo Failure?: $FAILURE
			if [ -n "$FAILURE" ]
			then
				FAILURE_COUNT=$((FAILURE_COUNT+1))
				echo Failure count: $FAILURE_COUNT
			fi
			if [ "$SPIDERED_INPUT_VALUES" = "1" ]
			then
				# The values should be correct, so we don't exit even if failurecount is high
				echo "Ignoring failurecount"
			elif [ "$FAILURE_COUNT" = "3" ]
			then
				echo "Exiting because of too many failures"
				# We have manually entered (input) values, so we exit if failurecount is too high
				exit 1
			fi	
		fi

		URL_RS=$((URL_RS+1))
	done
} 


#
#Start main procedure
#
#

#
#Set default values for variables
#
URL=null
URL_START=null
URL_END=null
START_RANGE=null
END_RANGE=null
# Do we have a spider generated input file? 0==we dont have
SPIDERED_INPUT_FILE=null
FAILURE_COUNT=0
# Temporary variable to store wget | grep
FAILURE=
# Are the manually inputted values ok?
INPUT_VALUES_OK=0
# If this is > 0 then the urls are spidered first to check if the filesize is big enough
MINIMUM_FILE_LENGTH=0

# wget -o destination file, which is removed after a suucessdul run 
WGET_LOG_FILE=wget.log

#
# if no arguments given
#
if [ $# -lt 1 ]; 
then
  help
fi

#
# Process startup options
#
while getopts s:e:l:h:f:b: opt
do
  case "$opt" in
    s) URL_START="$OPTARG";;
    e) URL_END="$OPTARG";;
    l) START_RANGE="$OPTARG";;
    h) END_RANGE="$OPTARG";;
    f) SPIDERED_INPUT_FILE="$OPTARG";;
    b) MINIMUM_FILE_LENGTH="$OPTARG";;
    \?) help;;
  esac
done

# Confirm if the script should continue...
confirmStartup

#
# Check input values
#
if [ "$SPIDERED_INPUT_FILE" == "null" ]
then
	# We need to check if the input values all exist & are somewhat correct
	if [ "$URL_START" != "null" ]
	then
		echo "-s (url_start) ok"
		INPUT_VALUES_OK=1
	else
		echo "-s (url_start) not ok"
		INPUT_VALUES_OK=0
	fi
	if [ "$URL_END" != "null" ]
	then
		echo "-e (url_end) ok"
		INPUT_VALUES_OK=1
	else
		echo "-e (url_end) not ok"
		INPUT_VALUES_OK=1
	fi
	if [ "$START_RANGE" != "null" ]
	then
		echo "-l (range_lower) ok"
		INPUT_VALUES_OK=1
	else
		echo "-l (range_lower) not ok"
		INPUT_VALUES_OK=0
	fi
	if [ "$END_RANGE" != "null" ]
	then
		echo "-h (range_higher) ok"
		INPUT_VALUES_OK=1
	else
		echo "-h (range_higher) not ok"
		INPUT_VALUES_OK=0
	fi
fi

if [ "$SPIDERED_INPUT_FILE" != "null" ]
then
	# We have a input file spesified
	# Process the file & download
	processInputFile
elif [ "$INPUT_VALUES_OK" -eq 1 ]
then
	# We need to use manually inputted values which have been checked & they're ok
	echo "Using manually entered values"
	download $URL_START $URL_END $START_RANGE $END_RANGE
else
	echo "No input file spesified and manual input values are incorrect"
	exit 1
fi

rm -f $WGET_LOG_FILE
