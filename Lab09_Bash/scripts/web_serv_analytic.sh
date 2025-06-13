#!/bin/bash
#Script for analyzing web server access log file

echo -e "Starting web server access log file analyzer script...\n"

###Check if a log  file is provided####################################################
##
if [ $# -eq 0 ]; then
   echo "A log file has not been specified!" >&2
   exit 1
fi  

######################################################################################


###Prevent script to start in case prevoius instance is already running####3###########
##
lockfile="/tmp/web_serv_analytic.lock"

if ! mkdir "$lockfile" 2>/dev/null; then
    echo "Another instance is still running..."
    exit 1
fi

#################At the end lockfile MUST BE RELEASED!################################
######################################################################################

### Get log file######################################################################
log_file="$1"
######################################################################################

##In order to get only new data since the last call, we store the number of log file
##lines  in a separate storage(file) and compare it every script call. If actual 
##value in log file bigger than storied we should read the new lines
##

## create if does not exist a file to store the number of lines in log file 
prev_numb_of_lines="/tmp/web_serv_analytic_store_data"

if  [ ! -f "$prev_numb_of_lines" ]; then
    touch "$prev_numb_of_lines"
    echo 1 > "$prev_numb_of_lines"
fi


#read the actual number of lines in log file:
num_read_lines="$( wc -l < $log_file)"

#read the number storied since the last call 
num_lines_storied=$(cat "$prev_numb_of_lines")

##DEBUG output####################################################################
#echo "Number of lines actually read ${num_read_lines}"
#echo "Number of lines storied in a file since last call ${num_lines_storied}"
##################################################################################

new_data_provided=0

if [[ "$num_read_lines" > "$num_lines_storied" ]]; then
    new_data_provided=1
fi



##Process log file content line by line in case new data provided#####################

temp_data_file="/tmp/web_serv_dat.t"
touch "$temp_data_file"

## read the data from lof file line by line from stroied value(prev.call) and actual 
## number of lines

if [ "$new_data_provided" -eq 1 ]; then

sed -n "${num_lines_storied},${num_read_lines}p" "$log_file" > "$temp_data_file"

fi


#update the number of lines
echo "$num_read_lines" > "$prev_numb_of_lines"
#####################################################################################


######################LOGIC FOR LOG DATA PROCESSING ################################ 

log_data_content=$(cat "$temp_data_file")

################## Get all IP addreses sorted and counted ##########################

ip_addresses=$(echo "$log_data_content" | awk '{print $1}' | sort | uniq -c | sort -n | tail -n 10)
 
####################################################################################

############################ Get all URL`s #########################################

url_regex='(http|https):\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/[^")]*)' 

urls=$(echo "$log_data_content" | grep -Eo "$url_regex" | sort | uniq -c | sort -n | tail -n 10)

####################################################################################

############################ Get all errors ########################################

error_regex='(error|warn|crit|alert|emerg)'

errors=$(echo "$log_data_content" | grep -Eo "error_regex" )

####################################################################################


############################Get all HTTP responses##################################

http_resp_regex='(HTTP/[0-9].[0-9]" [0-9]{3})'

http_responses=$(echo "$log_data_content" | grep -Eo  "$http_resp_regex" | sort | uniq -c | sort -n | tail -n 10)

###################################################################################

############################# Write parsed  data to the file ######################

data_file_prefix="web_serv_analytic"
date_time_suffix=$(date +'%Y_%m_%d_%H_%M_%S')

data_file="$data_file_prefix"."$date_time_suffix"

if [ "$new_data_provided" -eq 1 ]; then

   str_ip_addr="IP addreses:"
   ip_addr_res="$ip_addresses"
   
   str_URLS="URLs:"
   urls_result="$urls"

   str_HTTP_resp="HTTP responses:"
   HTTP_resp_res="$http_responses"
   
   str_serv_err="Server errors:"
   srv_err_res="$errors" 
  
   data_result=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$str_ip_addr" "$ip_addr_res"\
                           "$str_URLS" "$urls_result" "$str_HTTP_resp" "$HTTP_resp_res"\
                           "$str_serv_err" "$srv_err_res")
   
else
   data_result="No no data has been provided since the last script call"
fi 

   echo "$data_result">>"$data_file"

### Send Email####################################################################
send_email=1

if [ "$send_email" -eq 1 ]; then
  mail -s "Web server log report" otus <<EOF
  $data_result
EOF
fi
###################################################################################


#############Delete temp file and release lease lock file###################################
rm     "$temp_data_file"
rm -rf "$lockfile"
###################################################################################



echo "Web server access log file analyzer script has finished it\`s job. All data has been sent. HAVE A NICE DAY!"


echo $?
