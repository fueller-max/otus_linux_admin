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
12 
13
14
15 #Get CLK_TCK (sysconf(_SC_CLK_TCK) from C-compiled programm
16 CLK_TCK=$(./get_clk_tck)
17
18 #Get total Memory in bytes
19
20 MEM_TOTAL_KBYTES=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
21 MEM_TOTAL_BYTES=$(( MEM_TOTAL_KBYTES * 1024))
22
23
24 column_names=("PID   " "PPID  " "S    "  "CMD                                    " \
25               "%CPU  " "%MEM  " "VSZ     ")
26 echo "${column_names[@]}"
27
28
29 proc_dir="/proc"
30
31 
32
33
34 for subdir in $(find "$proc_dir" -maxdepth 1 -mindepth 1 -type d -regex "$proc_dir/[0-9]+")
35 do
36     process_data="$subdir$stat"
37     awk -v clk_tck="$CLK_TCK" -v total_mem="$MEM_TOTAL_BYTES" \
38        '{printf "%-6s %-6s %-5s %-39s %-6.2f %-6.2f %-10s\n", $1,$4,$3,$2,$14/clk_tck,$23/total_mem,$23/1024}' "$process_data"  \
39          2>/dev
33 done



#echo $?

