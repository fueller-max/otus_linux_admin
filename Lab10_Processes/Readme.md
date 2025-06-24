### Работа с процессами

### Цель:

Работать с процессами

###  Задание:

1. Написать свою реализацию ps ax используя анализ /proc. Результат - рабочий скрипт который можно запустить
2. Написать свою реализацию lsof. Результат  - рабочий скрипт который можно запустить

### Решение:


#### 1. Написать свою реализацию ps ax используя анализ /proc. Результат - рабочий скрипт который можно запустить

Выведем примеры команды ps с различными аргументами: 

````
root@otusadmin:/home/otus/scripts# ps aux | head -n 20
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.1  0.3  22216 13500 ?        Ss   15:21   0:01 /sbin/init
root           2  0.0  0.0      0     0 ?        S    15:21   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    15:21   0:00 [pool_workqueue_release]
root           4  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-rcu_gp]
root           5  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-sync_wq]
root           6  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-kvfree_rcu_reclaim]
root           7  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-slub_flushwq]
root           8  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-netns]
root          10  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/0:0H-events_highpri]
root          11  0.1  0.0      0     0 ?        I    15:21   0:01 [kworker/0:1-events]
root          12  0.0  0.0      0     0 ?        I    15:21   0:00 [kworker/u512:0-ipv6_addrconf]
root          13  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-mm_percpu_wq]
root          14  0.0  0.0      0     0 ?        I    15:21   0:00 [rcu_tasks_kthread]
root          15  0.0  0.0      0     0 ?        I    15:21   0:00 [rcu_tasks_rude_kthread]
root          16  0.0  0.0      0     0 ?        I    15:21   0:00 [rcu_tasks_trace_kthread]
root          17  0.0  0.0      0     0 ?        S    15:21   0:00 [ksoftirqd/0]
root          18  0.0  0.0      0     0 ?        I    15:21   0:00 [rcu_preempt]
root          19  0.0  0.0      0     0 ?        S    15:21   0:00 [rcu_exp_par_gp_kthread_worker/1]
root          20  0.0  0.0      0     0 ?        S    15:21   0:00 [rcu_exp_gp_kthread_worker]

````
````
root@otusadmin:/home/otus/scripts# ps -aux | head -n 10
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.3  22364 13500 ?        Ss   15:21   0:01 /sbin/init
root           2  0.0  0.0      0     0 ?        S    15:21   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    15:21   0:00 [pool_workqueue_release]
root           4  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-rcu_gp]
root           5  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-sync_wq]
root           6  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-kvfree_rcu_reclaim]
root           7  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-slub_flushwq]
root           8  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/R-netns]
root          10  0.0  0.0      0     0 ?        I<   15:21   0:00 [kworker/0:0H-events_highpri]

````

Ниже дано описание некоторых параметров, получаемых с помощью команды ps:
````
USER = user owning the process
PID = process ID of the process
%CPU = It is the CPU time used divided by the time the process has been running.
%MEM = ratio of the process’s resident set size to the physical memory on the machine
VSZ = virtual memory usage of entire process (in KiB)
RSS = resident set size, the non-swapped physical memory that a task has used (in KiB)
TTY = controlling tty (terminal)
STAT = multi-character process state
START = starting time or date of the process
TIME = cumulative CPU time
COMMAND = command with all its arguments
````

Удалось релизовать скрипт, который выдает такие основные результаты:

````
root@otusadmin:/home/otus/scripts# ./myps.sh | head -n 10
PID    PPID   S     CMD                                     %CPU   %MEM   VSZ
1      0      S     (systemd)                               0.20   0.01   22364
2      0      S     (kthreadd)                              0.00   0.00   0
3      2      S     (pool_workqueue_release)                0.00   0.00   0
4      2      I     (kworker/R-rcu_gp)                      0.00   0.00   0
5      2      I     (kworker/R-sync_wq)                     0.00   0.00   0
6      2      I     (kworker/R-kvfree_rcu_reclaim)          0.00   0.00   0
7      2      I     (kworker/R-slub_flushwq)                0.00   0.00   0
8      2      I     (kworker/R-netns)                       0.00   0.00   0
10     2      I     (kworker/0:0H-events_highpri)           0.00   0.00   0
````

Описание скрипта:

* в основе работы скрипта лежит извлечение информации из файловой структуры всех процессов "/proc/*/stat", где * - PID процесса (число).

Необходимо пройтись по всем подкаталогам "/proc/", но только по каталогами с числовым значением(используем регулярное выражение):

````
proc_dir="/proc"
stat="/stat"
for subdir in $(find "$proc_dir" -maxdepth 1 -mindepth 1 -type d -regex "$proc_dir/[0-9]+")
````

* Далее, используя документацию по "stat", где описаны на какой позции находится тот или иной параметр, выводим данные.

Для расчета относительного потребления CPU процессом необходимо иметь значение sysconf(_SC_CLK_TCK), которое получаем из небольшой программы на C:

````
 #include <stdio.h>
    #include <unistd.h>

    int main() {
        long clk_tck = sysconf(_SC_CLK_TCK);
        if (clk_tck == -1) {
            perror("sysconf");
            return 1;
        }
        printf("%ld\n", clk_tck);
        return 0;
    }

````
Эта программа предварительно скомпилирована в .obj файл и используется в работе скрипта:

````
gcc -o get_clk_tck get_clk_tck.c
````

````
CLK_TCK=$(./get_clk_tck)
````

Также получаем данные о суммарной доступной физичиской памяти системы(без С-программы:))

````
MEM_TOTAL_KBYTES=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
MEM_TOTAL_BYTES=$(( MEM_TOTAL_KBYTES * 1024))

````

Далее выводим данные(некоторые на прямую, некоторые делим на полученные константы):

````
column_names=("PID   " "PPID  " "S    "  "CMD                                    " \
               "%CPU  " "%MEM  " "VSZ     ")
 echo "${column_names[@]}"

do
     process_data="$subdir$stat"
     awk -v clk_tck="$CLK_TCK" -v total_mem="$MEM_TOTAL_BYTES" \
        '{printf "%-6s %-6s %-5s %-39s %-6.2f %-6.2f %-10s\n", $1,$4,$3,$2,$14/clk_tck,$23/total_mem,$23/1024}' "$process_data"  \
          2>/dev/null
 done

````

Безусловно, это не является полноценной заменой утилиты ps, однако скрипт выдает базовую информацию, а также продемонстрирован способ, как можно получить данные без использования сторонних средств.



#### 2. Написать свою реализацию lsof. Результат  - рабочий скрипт который можно запустить

Пример вывода команды lsof для одного из процессов:

````
root@otusadmin:/home/otus/scripts# lsof -p 3423
COMMAND  PID USER   FD      TYPE             DEVICE SIZE/OFF   NODE NAME
upowerd 3423 root  cwd       DIR              252,0     4096      2 /
upowerd 3423 root  rtd       DIR              252,0     4096      2 /
upowerd 3423 root  txt       REG              252,0   145856 845563 /usr/libexec/upowerd
upowerd 3423 root  mem       REG              252,0  3055776 787375 /usr/lib/locale/locale-archive
upowerd 3423 root  mem       REG              252,0  5305304 806146 /usr/lib/x86_64-linux-gnu/libcrypto.so.3
upowerd 3423 root  mem       REG              252,0    27028 823127 /usr/lib/x86_64-linux-gnu/gconv/gconv-modules.cache
upowerd 3423 root  mem       REG              252,0    51536 807440 /usr/lib/x86_64-linux-gnu/libcap.so.2.66
upowerd 3423 root  mem       REG              252,0   236592 798710 /usr/lib/x86_64-linux-gnu/libblkid.so.1.1.0
upowerd 3423 root  mem       REG              252,0    43016 826004 /usr/lib/x86_64-linux-gnu/libusbmuxd-2.0.so.6.0.0
upowerd 3423 root  mem       REG              252,0   696512 806148 /usr/lib/x86_64-linux-gnu/libssl.so.3
upowerd 3423 root  mem       REG              252,0   207288 787573 /usr/lib/x86_64-linux-gnu/libudev.so.1.7.8
upowerd 3423 root  mem       REG              252,0   174472 798921 /usr/lib/x86_64-linux-gnu/libselinux.so.1
upowerd 3423 root  mem       REG              252,0   625344 798893 /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0.11.2
upowerd 3423 root  mem       REG              252,0   952616 823141 /usr/lib/x86_64-linux-gnu/libm.so.6
upowerd 3423 root  mem       REG              252,0  2125328 823138 /usr/lib/x86_64-linux-gnu/libc.so.6
upowerd 3423 root  mem       REG              252,0   309960 798845 /usr/lib/x86_64-linux-gnu/libmount.so.1.1.0
upowerd 3423 root  mem       REG              252,0   113000 798990 /usr/lib/x86_64-linux-gnu/libz.so.1.3
upowerd 3423 root  mem       REG              252,0    22736 802284 /usr/lib/x86_64-linux-gnu/libgmodule-2.0.so.0.8000.0
upowerd 3423 root  mem       REG              252,0    47672 798756 /usr/lib/x86_64-linux-gnu/libffi.so.8.1.4
upowerd 3423 root  mem       REG              252,0   100344 825998 /usr/lib/x86_64-linux-gnu/libplist-2.0.so.4.3.0
upowerd 3423 root  mem       REG              252,0   153712 826012 /usr/lib/x86_64-linux-gnu/libimobiledevice-1.0.so.6.0.0
upowerd 3423 root  mem       REG              252,0    51272 798790 /usr/lib/x86_64-linux-gnu/libgudev-1.0.so.0.3.0
upowerd 3423 root  mem       REG              252,0  1887792 802282 /usr/lib/x86_64-linux-gnu/libgio-2.0.so.0.8000.0
upowerd 3423 root  mem       REG              252,0   399752 802285 /usr/lib/x86_64-linux-gnu/libgobject-2.0.so.0.8000.0
upowerd 3423 root  mem       REG              252,0  1343056 802283 /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0.8000.0
upowerd 3423 root  mem       REG              252,0   129096 826023 /usr/lib/x86_64-linux-gnu/libupower-glib.so.3.1.0
upowerd 3423 root  mem       REG              252,0   236616 823135 /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
upowerd 3423 root    0r      CHR                1,3      0t0      5 /dev/null
upowerd 3423 root    1u     unix 0xffff88fedd05e800      0t0  27419 type=STREAM (CONNECTED)
upowerd 3423 root    2u     unix 0xffff88fedd05e800      0t0  27419 type=STREAM (CONNECTED)
upowerd 3423 root    3u  a_inode               0,16        0   1062 [eventfd:30]
upowerd 3423 root    4u  a_inode               0,16        0   1062 [eventfd:31]
upowerd 3423 root    5u     unix 0xffff88fedd05cc00      0t0  27429 type=STREAM (CONNECTED)
upowerd 3423 root    6u  a_inode               0,16        0   1062 [eventfd:32]
upowerd 3423 root    7w     FIFO               0,26      0t0   2012 /run/systemd/inhibit/3.ref
upowerd 3423 root    8u  netlink                         0t0  27432 KOBJECT_UEVENT
upowerd 3423 root    9u  netlink                         0t0  27436 KOBJECT_UEVENT


````

Реализуем упрощенную версию lsof, которая будет выводить список используемых файлов всеми процессами.

В основе работы используем сканирование директории "proc/*/fd", где содержатся все ссылки на используемые файлы для каждого процесса:

````
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

````

Скрипт использует два вложенных for цикла - один для итерации по процессам (полностью аналогичен myps), а вложенный для итерации по директории fd. Если директория представялет собой simlink - то выводим результат: PID + simlink


Пример  работы скрипта:


````
root@otusadmin:/home/otus/scripts# ./mylsof.sh | tail -n 50
PID: 2549   FILE: /dev/pts/1
PID: 2549   FILE: /dev/pts/1
PID: 2549   FILE: /dev/pts/1
PID: 2549   FILE: socket:[25304]
PID: 2550   FILE: /dev/pts/1
PID: 2550   FILE: /dev/pts/1
PID: 2550   FILE: /dev/pts/1
PID: 2550   FILE: /dev/pts/1
PID: 3416   FILE: /dev/null
PID: 3416   FILE: socket:[27391]
PID: 3416   FILE: anon_inode:[eventfd]
PID: 3416   FILE: socket:[28467]
PID: 3416   FILE: anon_inode:[eventfd]
PID: 3416   FILE: socket:[27440]
PID: 3416   FILE: socket:[27391]
PID: 3416   FILE: anon_inode:[eventfd]
PID: 3416   FILE: anon_inode:inotify
PID: 3416   FILE: anon_inode:[eventfd]
PID: 3416   FILE: /var/lib/fwupd/pending.db
PID: 3416   FILE: anon_inode:[eventfd]
PID: 3416   FILE: anon_inode:[timerfd]
PID: 3416   FILE: socket:[27403]
PID: 3423   FILE: /dev/null
PID: 3423   FILE: socket:[27419]
PID: 3423   FILE: socket:[27419]
PID: 3423   FILE: anon_inode:[eventfd]
PID: 3423   FILE: anon_inode:[eventfd]
PID: 3423   FILE: socket:[27429]
PID: 3423   FILE: anon_inode:[eventfd]
PID: 3423   FILE: /run/systemd/inhibit/3.ref
PID: 3423   FILE: socket:[27432]
PID: 3423   FILE: socket:[27436]
PID: 11819  FILE: /dev/null
PID: 11819  FILE: /dev/null
PID: 11819  FILE: pipe:[52762]
PID: 11819  FILE: /dev/null
PID: 11819  FILE: pipe:[23820]
PID: 11819  FILE: pipe:[23820]
PID: 11819  FILE: socket:[23744]
PID: 11819  FILE: socket:[23742]
PID: 11819  FILE: socket:[52751]
PID: 11819  FILE: anon_inode:[eventpoll]
PID: 11819  FILE: pipe:[52762]
PID: 40977  FILE: /dev/pts/1
PID: 40977  FILE: pipe:[113981]
PID: 40977  FILE: /dev/pts/1
PID: 40977  FILE: /home/otus/scripts/mylsof.sh
PID: 40978  FILE: pipe:[113981]
PID: 40978  FILE: /dev/pts/1
PID: 40978  FILE: /dev/pts/1

````

Оба скрипта помещены в папке "scripts"


