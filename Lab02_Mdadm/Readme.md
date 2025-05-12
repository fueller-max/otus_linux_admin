### Работа с mdadm

### Цель:

Научиться использовать утилиту для управления программными RAID-массивами в Linux

###  Задание:

1. Добавить в виртуальную машину несколько дисков
2. Собрать RAID-0/1/5/10 на выбор
3. Сломать и починить RAID
4. Создать GPT таблицу, пять разделов и смонтировать их в системе.


### Решение:

1. [Добавить в виртуальную машину несколько дисков](Readme.md#1-добавить-в-виртуальную-машину-несколько-дисков)
2. [Собрать RAID-0/1/5/10 на выбор](Readme.md#2-собрать-raid-01510-на-выбор)
3. [Сломать и починить RAID](Readme.md#3-сломать-и-починить-raid)
4. [Создать GPT таблицу, пять разделов и смонтировать их в системе](Readme.md#4-создать-gpt-таблицу-пять-разделов-и-смонтировать-их-в-системе)


#### 1. Добавить в виртуальную машину несколько дисков

Добавим в машину 4 диска объемом 1 GB (с планированием создать RAID(1+0)):

![](/Lab02_Mdadm/pic/Additional%20disks.jpg)


Проверяем, что диски добавлены  в систему, используя команду disk -l

````
otus@otusadmin:~$ sudo fdisk -l
[sudo] password for otus:
Disk /dev/sda: 40 GiB, 42949672960 bytes, 83886080 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 06ABA0BD-66E8-4A7D-A501-3A5AC1F1EE0F

Device       Start      End  Sectors Size Type
/dev/sda1     2048     4095     2048   1M BIOS boot
/dev/sda2     4096  4198399  4194304   2G Linux filesystem
/dev/sda3  4198400 83884031 79685632  38G Linux filesystem


Disk /dev/sdb: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdc: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sde: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes

````
Как видно, все диски добавлены в систему. 

Добавленные диски для RAID массива:
````
/dev/sdb
/dev/sdc
/dev/sdd
/dev/sde
````

#### 2. Собрать RAID-0/1/5/10 на выбор

Приступаем к сборке RAID10 массива из 4х дисков:

````
otus@otusadmin:~$ sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}

mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 1046528K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.

````

Проверяем сборку RAID:

````
otus@otusadmin:~$ cat /proc/mdstat

md0 : active raid10 sde[3] sdd[2] sdc[1] sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

````


````
otus@otusadmin:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon May 12 10:28:43 2025
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon May 12 10:28:53 2025
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otusadmin:0  (local to host otusadmin)
              UUID : eb44749c:2fc74cf2:f02a15fa:eb4afbe6
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

````
Как видими, RAID собрался и находится в состоянии "clean", т.е. в рабочем и все диски ОК.


Создадим файловую систему на RAID:

````
otus@otusadmin:~$ sudo mkfs.ext4 /dev/md0
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 523264 4k blocks and 130816 inodes
Filesystem UUID: 48bc3b67-07e6-4625-b77c-c0eae01daa63
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

````
И смонтируем созданный RAID в каталог /mnt/01:

````
otus@otusadmin:~$ sudo mkdir /mnt/01
otus@otusadmin:~$ sudo mount /dev/md0 /mnt/01
````

Посмотрим результаты:

````
otus@otusadmin:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              387M  1.6M  386M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   19G  6.8G   11G  39% /
tmpfs                              1.9G     0  1.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  189M  1.7G  11% /boot
tmpfs                              387M   12K  387M   1% /run/user/1000
/dev/md0                           2.0G   24K  1.9G   1% /mnt/01

````

Видим, что есть созданный RAID, объемом 2Gb (как и должно было получится для RAID 10 с 4мя дисками объемом 1Gb каждый), который смонитирован в каталог
/mnt/01


#### 3. Сломать и починить RAID

Имитируем сбой одного диска (2ой диск RAID 1 подмассива)

````
otus@otusadmin:~$ sudo mdadm /dev/md0 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0
````

Проверяем состояние RAID:
````
otus@otusadmin:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon May 12 10:28:43 2025
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon May 12 10:45:48 2025
             State : clean, degraded
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otusadmin:0  (local to host otusadmin)
              UUID : eb44749c:2fc74cf2:f02a15fa:eb4afbe6
            Events : 19

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       -       0        0        1      removed
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

       1       8       32        -      faulty   /dev/sdc

````

Видно, что RAID в работе, но имеет состояние "degraded" 

Пробуем удалить еще один диск (тоже 2ой из второго RAID 1 подмассива):

````
otus@otusadmin:~$ sudo mdadm /dev/md0 --fail /dev/sde
mdadm: set /dev/sde faulty in /dev/md0
otus@otusadmin:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon May 12 10:28:43 2025
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon May 12 10:51:39 2025
             State : clean, degraded
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 2
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otusadmin:0  (local to host otusadmin)
              UUID : eb44749c:2fc74cf2:f02a15fa:eb4afbe6
            Events : 21

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       -       0        0        1      removed
       2       8       48        2      active sync set-A   /dev/sdd
       -       0        0        3      removed

       1       8       32        -      faulty   /dev/sdc
       3       8       64        -      faulty   /dev/sde

````

Как видно, что RAID все еще в работе с двумя дисками.

Пробуем удалить еще один диск:

````
otus@otusadmin:~$ sudo mdadm /dev/md0 --fail /dev/sdb
mdadm: Cannot remove /dev/sdb from /dev/md0, array will be failed.

````

Ожидаемо система не дает этого сделать, т.к. для данного RAID минимум 2 диска(по одному в каждом RAID1) должны быть в работе, иначе это приведет к краху RAID.


Проведем также тест с удалением одного неисправного диска из RAID и последующи его добавлением обратно в RAID:

````
otus@otusadmin:~$ sudo mdadm /dev/md0 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0

otus@otusadmin:~$ sudo mdadm /dev/md0 --remove /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md0

otus@otusadmin:~$ sudo mdadm /dev/md0 --add /dev/sdc
mdadm: added /dev/sdc
otus@otusadmin:~$ cat /proc/mdstat
Personalities : [linear] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10]
md0 : active raid10 sdc[4] sde[5] sdd[2] sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/3] [U_UU]
      [=======>.............]  recovery = 38.2% (401024/1046528) finish=0.0min speed=401024K/sec

unused devices: <none>

````
как и ожидалось, после добавления диска, система выполняет копирование данных с остальных, находясь какое-то время в состоянии "recovery"


#### 4. Создать GPT таблицу, пять разделов и смонтировать их в системе

Для начала отмонтируем существующий RAID от каталога:

````
otus@otusadmin:~$ sudo unmount /dev/md0
````

Создаем раздел GPT:

````
sudo parted -s /dev/md0 mklabel gpt
````

И 5 партиций равного размера:

````
otus@otusadmin:~$ parted /dev/md0 mkpart primary ext4 0% 20%
otus@otusadmin:~$ parted /dev/md0 mkpart primary ext4 20% 40%
otus@otusadmin:~$ parted /dev/md0 mkpart primary ext4 40% 60%
otus@otusadmin:~$ parted /dev/md0 mkpart primary ext4 60% 80%
otus@otusadmin:~$ parted /dev/md0 mkpart primary ext4 80% 100%
````

Проверим результат действий:

````
otus@otusadmin:~$ sudo parted /dev/md0
GNU Parted 3.6
Using /dev/md0
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) print
Model: Linux Software RAID Array (md)
Disk /dev/md0: 2143MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size   File system  Name     Flags
 1      1049kB  429MB   428MB               primary
 2      429MB   858MB   429MB               primary
 3      858MB   1286MB  428MB               primary
 4      1286MB  1714MB  429MB               primary
 5      1714MB  2142MB  428MB               primary

````

Видим, что создался раздел GPT и 5 партиций.

Создадим файловую систему на каждом из разделов:

````

otus@otusadmin:~$ for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 8c5cf924-7ad9-4d9a-8bf7-c28295d62fd5
Superblock backups stored on blocks:
        32768, 98304

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

.....

````

Создаем и монтируем разделы к каталогам:

````
otus@otusadmin:~$ sudo mkdir -p /mnt/part{1,2,3,4,5}
````

````
otus@otusadmin:~$ for i in $(seq 1 5); do sudo mount /dev/md0p$i /mnt/part$i; done
````

проверяем результат действий:

````
otus@otusadmin:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              387M  1.6M  386M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   19G  6.8G   11G  39% /
tmpfs                              1.9G     0  1.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  189M  1.7G  11% /boot
tmpfs                              387M   12K  387M   1% /run/user/1000
/dev/md0p1                         366M   24K  338M   1% /mnt/part1
/dev/md0p2                         367M   24K  339M   1% /mnt/part2
/dev/md0p3                         366M   24K  338M   1% /mnt/part3
/dev/md0p4                         367M   24K  339M   1% /mnt/part4
/dev/md0p5                         366M   24K  338M   1% /mnt/part5
````

Видим, что созданные разделы смонтированы к соответствующим каталогам.


