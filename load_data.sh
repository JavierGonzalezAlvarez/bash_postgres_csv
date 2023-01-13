#!/bin/bash
#------------ GLOBAL VARIABLES ---------------

THIS_SCRIPT=$(basename "$0")
DATA_HOME=./files
LOG_DIR=./logs
CREDENTIALS=credentials

#------------ Commands ---------------

MD5_COMMAND=/usr/bin/md5sum
CURL_COMMAND=/usr/bin/curl

# -------- Set time variables---------

TIME=`date +%Y-%m-%d-%H-%M-%S`
TODAY=${TIME:0:10}
YESTERDAY=`date +%Y-%m-%d -d "1 day ago"`

# ---------- DEFAULT VARIABLES -----------------

bLOAD=false
bLOADED=false
bDEBUG=false
INSTANCE=1
SLEEP_TIME=0
SOURCE_NAME=data
VIEW_NAME=${TABLE_DATA}

# ----------- FUNCTIONS --------------

usage() {
    echo "
Usage: ${THIS_SCRIPT} [-h | --help] [-i instance_number ] [-s source_name]"
    echo "            [--debug] [--load] [--sleep=secs]"
    echo "
Options :
 --help | -h                         Display this usage information
 -i instance_number                  Instance 1,2,3,4... Suffix as reference of the instance. 1 by default
 -s source_name                      Name of the data source : data (default)
 --debug                             Show debug messages
 --load                              Load data from default db and store into a target file
 --sleep=secs                        Sleep time between calls
    "
}

debug(){
    if [ $bDEBUG == true ]; then
         echo "$1"
    fi
}

debug_in() {
    debug "[$(date)] [$1 ...]"
}

debug_out() {
    debug "[$(date)] [... $1 ]"
}

debug_date() {
    debug "Date: $(date)"
}

exit_ifnotset(){
    if [ -z ${2+x} ]; then
        echo "$1 is not set. Configure it on your environment";
        exit 2 ;
    fi
}

run_psql() {
    psql -h ${DBHOST} -p ${DBPORT} -U ${DBUSER} -d ${DBNAME} -c "${1};"
}

set_paths() {

    # -------- Set endpoints and table names
    case $1 in
        data )  VIEW_NAME=${TABLE_DATA}
                    ENDPOINT=data ;;

        * )  echo "Illegal source name : '$1' Allowed values : data" >&2; exit 2 ;;
    esac

    # -------- Set paths and log names
    DATA_DIR=$DATA_HOME/${1}_v${2}

    # File to download
    TMP_DIR=$DATA_DIR/tmp
    INTERMEDIATE_FILE=$TMP_DIR/${1}_${TIME}.csv

    # All the files for today.
    TARGET_DIR=$DATA_DIR/$TODAY
    YESTEDAY_TARGET_DIR=$DATA_DIR/$YESTERDAY

    # Logs
    PREFIX=${1}_l${2}
    LOG_COLLECT_FILE=$LOG_DIR/${PREFIX}_load_csv.log

}

load_csv() {

    debug_in "Load csv"

    LOAD_FILE=$1
    mkdir -p $DATA_HOME
    mkdir -p $DATA_DIR
    mkdir -p $TMP_DIR
    mkdir -p $LOG_DIR

    # Load csv from psql
    run_psql "\copy (select * from ${VIEW_NAME}) to '$LOAD_FILE' csv header"
    LOAD_TIME=`date +%Y-%m-%d-%H-%M-%S`

    # Compute MD5
    TARGET_MD5=`${MD5_COMMAND} $LOAD_FILE | awk '{ print $1 }'`

    # Target to store
    mkdir -p $TARGET_DIR
    TARGET_FILE=$TARGET_DIR/$TARGET_MD5
    YESTERDAY_TARGET_FILE=$YESTERDAY_TARGET_DIR/$TARGET_MD5

    if [ -f  "$TARGET_FILE" ] || [ -f "$YESTERDAY_TARGET_FILE" ] ; then
        echo "$TIME, $LOAD_TIME, $LOAD_FILE, $TARGET_FILE : data already uploaded" >> $LOG_COLLECT_FILE
        rm $LOAD_FILE
        bLOADED=false
    else
        mv $LOAD_FILE $TARGET_FILE
        echo "$TIME, $LOAD_TIME, $LOAD_FILE, $TARGET_FILE" >> $LOG_COLLECT_FILE
        bLOADED=true
    fi

    debug_out "data loaded from ${VIEW_NAME} - is it ok?: ${bLOADED}"

    echo "------------------------------------------------------------" >> $LOG_DIR/data_loaded.log
    echo "execution date: $TIME - $LOAD_TIME ">> $LOG_DIR/data_loaded.log
    echo "load file $LOAD_FILE" >> $LOG_DIR/data_loaded.log
    echo "end loading data from - ${VIEW_NAME} - is loaded? (Result: true/false, false means already loaded): ${bLOADED}" >> $LOG_DIR/data_loaded.log
    echo "log_collect_file  - $LOG_COLLECT_FILE" >> $LOG_DIR/data_loaded.log
    echo "data_dir - instance folder (data_v1/data_v2) - $DATA_DIR" >> $LOG_DIR/data_loaded.log
    echo "target file - $TARGET_FILE" >> $LOG_DIR/data_loaded.log
    echo "file created- $TARGET_MD5" >> $LOG_DIR/data_loaded.log
    echo "intermediate_file - $INTERMEDIATE_FILE" >> $LOG_DIR/data_loaded.log

}

data() {
    if [ $1 == true ]; then
       load_csv $INTERMEDIATE_FILE
    fi
}

# -------------------------- MENU ------------------------

if [  $# -eq 0 ]; then
    usage
    exit 1
fi

while getopts c:p:i:s:h-: arg; do
  case $arg in
    h )  usage; exit 0;;
    i )  INSTANCE=$OPTARG ;;
    s )  SOURCE_NAME="$OPTARG";;
    c )  CREDENTIALS="$OPTARG";;
    p )  HOST="$OPTARG";;
    - )  LONG_OPTARG="${OPTARG#*=}"
         case $OPTARG in
           help) usage ; exit 0;;
           load) bLOAD=true;;
           sleep=?* ) SLEEP_TIME=${LONG_OPTARG};;
           debug) bDEBUG=true;;
           '' )        break ;;
           * )         echo "this option doesn't exist --$OPTARG" >&2; exit 2 ;;
         esac ;;
    \? ) exit 2 ;; 
  esac
done
shift $((OPTIND-1))

# ----------- SET ENVIRONMENT -----------------

if [ -f "${CREDENTIALS}" ]; then
    . $CREDENTIALS
else
    echo "file for credentials not found : ${CREDENTIALS}";
    exit 2 ;
fi

exit_ifnotset 'HOST' ${HOST}
exit_ifnotset 'PROTOCOL' ${PROTOCOL}
exit_ifnotset 'DBHOST' ${DBHOST}
exit_ifnotset 'DBPORT' ${DBPORT}
exit_ifnotset 'DBNAME' ${DBNAME}
exit_ifnotset 'USERDB' ${DBUSER}
exit_ifnotset 'TABLE_DATA' ${TABLE_DATA}

if [ $SOURCE_NAME == "data" ]; then
    set_paths $SOURCE_NAME $INSTANCE
    data $bLOAD
fi