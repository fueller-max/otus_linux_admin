### Работа с процессами

### Цель:

Работать с процессами

###  Задание:

1. Написать свою реализацию ps ax используя анализ /proc. Результат - рабочий скрипт который можно запустить
2. Написать свою реализацию lsof. Результат  - рабочий скрипт который можно запустить

### Решение:

````
otus@otusadmin:~$ ps -elf | head -n 20
F S UID          PID    PPID  C PRI  NI ADDR SZ WCHAN  STIME TTY          TIME CMD
4 S root           1       0  0  80   0 -  5624 -      14:15 ?        00:00:02 /sbin/init
1 S root           2       0  0  80   0 -     0 -      14:15 ?        00:00:00 [kthreadd]
1 S root           3       2  0  80   0 -     0 -      14:15 ?        00:00:00 [pool_workqueue_release]
1 I root           4       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-rcu_gp]
1 I root           5       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-sync_wq]
1 I root           6       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-kvfree_rcu_reclaim]
1 I root           7       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-slub_flushwq]
1 I root           8       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-netns]
1 I root          11       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/0:0H-events_highpri]
1 I root          12       2  0  80   0 -     0 -      14:15 ?        00:00:00 [kworker/u512:0-ipv6_addrconf]
1 I root          13       2  0  60 -20 -     0 -      14:15 ?        00:00:00 [kworker/R-mm_percpu_wq]
1 I root          14       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_tasks_kthread]
1 I root          15       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_tasks_rude_kthread]
1 I root          16       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_tasks_trace_kthread]
1 S root          17       2  0  80   0 -     0 -      14:15 ?        00:00:00 [ksoftirqd/0]
1 I root          18       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_preempt]
1 S root          19       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_exp_par_gp_kthread_worker/1]
1 S root          20       2  0  80   0 -     0 -      14:15 ?        00:00:00 [rcu_exp_gp_kthread_worker]
1 S root          21       2  0 -40   - -     0 -      14:15 ?        00:00:00 [migration/0]

````

````
UID – the user id of the process owner
PPID – the parent process id (in this particular snippet, rcu_gp was spawned by kthread)
C – the CPU utilization in percentage
STIME – the start time of the process
````

````
/proc/3572/stat
````

