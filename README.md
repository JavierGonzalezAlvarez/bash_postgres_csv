# load data remotely from postgres to csv files

## postgres
CREATE DATABASE load_data_bash WITH OWNER test;
CREATE USER test WITH password '2525_ap';

## run script bash, some options below:
./load_data.sh
./load_data.sh -i 1 -s data --load 
./load_data.sh -i 1 -s data --load --sleep=2
./load_data.sh -i 1 -s data --load --debug