#!/bin/bash

#****************************************************************************************#
#                                                                                        #
#                                      mylsof.sh                                         #
#                      Custom implementation of ps utility                               #
#                        May 2025  Maksim Ovchinnikov                                    #
#                                                                                        #
#****************************************************************************************#

proc_dir="/proc"
stat="/stat"
fd="/fd/"



for subdir in $(find "$proc_dir" -maxdepth 1 -mindepth 1 -type d -regex "$proc_dir/[0-9]+"); do
     process_data="$subdir$stat"
     pid=$(awk  '{printf "%-6s", $1}' "$process_data"  2>/dev/nul)  #Get PID number


     for fd_ in "$subdir$fd"*; do                   #Iterate over all subdir in /proc/*/fd/*
       if [ -L "$fd_" ]; then                       #check if dia a symbolik link
         target=$(readlink "$fd_")
         echo "PID: $pid FILE: $target"             #Ourput PID + FILE
       fi
     done
done

