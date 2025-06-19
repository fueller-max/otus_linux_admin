#!/bin/bash
 2
 3 #****************************************************************************************#
 4 #                                                                                        #
 5 #                                      myps.sh                                           #
 6 #                      Custom implementation of ps utility                               #
 7 #                        May 2025  Maksim Ovchinnikov                                    #
 8 #                                                                                        #
 9 #****************************************************************************************#
10
11
12 #process_data_f='/proc/3572/stat'
13
14
15 column_names=("PID   " "PPID  " "STATE"  "COMM                                  ")
16 echo "${column_names[@]}"
17
18
19 proc_dir="/proc"
20
21 stat="/stat"
22
23
24 for subdir in $(find "$proc_dir" -maxdepth 1 -mindepth 1 -type d -regex "$proc_dir/[0-9]+")
25 do
26     process_data="$subdir$stat"
27     awk '{printf "%-6s %-6s %-5s %-39s\n", $1,$4,$3,$2}' "$process_data"  2>/dev/null
28 done
29
30
31
32 #echo $?
33
