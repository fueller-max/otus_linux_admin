### Работа с LVM

### Цель:

Cоздавать и управлять логическими томами в LVM

###  Задание:

1. Создать Physical Volume, Volume Group и Logical Volume
2. Отформатировать и смонтировать файловую систему
3. Расширить файловую систему за счёт нового диска
4. Выполнить resize
5. Проверить корректность работы
6. *Работа со снапшотами  
7. *Работа LVM-RAID


### Решение:

1. [Создание Physical Volume, Volume Group и Logical Volume](Readme.md#1-создание-physical-volume-volume-group-и-logical-volume)
2. [Форматирование и монтаж файловой системы](Readme.md#2-форматирование-и-монтаж-файловой-системы)
3. [Расширение файловой системы за счёт нового диска](Readme.md#3-расширение-файловой-системы-за-счёт-нового-диска)
4. [Выполнение resize](Readme.md#4-выполнение-resize)
5. [Проверка корректности работы](Readme.md#5-проверка-корректности-работы)
6. [Работа со снапшотами](Readme.md#6-работа-со-снапшотами)
7. [Работа LVM-RAID](Readme.md#7-работа-lvm-raid)


#### 1. Создание Physical Volume, Volume Group и Logical Volume

Приступим к созданию PV,VG, LV в соответствии с приведенной схемой:

![](/Lab03_LVM/pic/LVM_1.jpg)

Для работы с LVM будем использовать доступные блочные устройства /dev/sdf, /dev/sdg, /dev/sdh, /dev/sdi.


````
root@otusadmin:~# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
sda                         8:0    0   40G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0    2G  0 part   /boot
└─sda3                      8:3    0   38G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0   19G  0 lvm    /
sdb                         8:16   0    1G  0 disk
└─md127                     9:127  0    2G  0 raid10
#
sdc                         8:32   0    1G  0 disk
└─md127                     9:127  0    2G  0 raid10
#  
sdd                         8:48   0    1G  0 disk
└─md127                     9:127  0    2G  0 raid10
#  
sde                         8:64   0    1G  0 disk
└─md127                     9:127  0    2G  0 raid10
#
sdf                         8:80   0    1G  0 disk
sdg                         8:96   0    1G  0 disk
sdh                         8:112  0    1G  0 disk
sdi                         8:128  0    1G  0 disk
sr0                        11:0    1 1024M  0 rom
````

На данном этапе используем только одно блочное устройство /dev/sdf.

 1. Создаем PV (Physical Volume) на блочном устройстве /dev/sdf(целиком):

  
 ````
 root@otusadmin:~# pvcreate /dev/sdf
  Physical volume "/dev/sdf" successfully created.
 ````
  2. Создаем VG(Volume Group) 'datavg', куда включаем только что созданный PV:

  ````
  root@otusadmin:~# vgcreate datavg /dev/sdf
    Volume group "datavg" successfully created
  ````

  3. Создаем LV(Logical Volume) с именем 'data' объемом 700Mb в созданном VG 'datavg':

  `````
  root@otusadmin:~# lvcreate -n data -L700M datavg
  Logical volume "data" created.
  `````
  Проверим результат выполненных действий:

  ````
  root@otusadmin:~# vgdisplay -v datavg

  --- Volume group ---
  VG Name               datavg
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               0
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               1020.00 MiB
  PE Size               4.00 MiB
  Total PE              255
  Alloc PE / Size       175 / 700.00 MiB
  Free  PE / Size       80 / 320.00 MiB
  VG UUID               EhRfTH-ancP-457S-god1-VV13-Kd6B-aM82Ik

  --- Logical volume ---
  LV Path                /dev/datavg/data
  LV Name                data
  VG Name                datavg
  LV UUID                FdkiT1-ZbV7-7cUW-6ZrG-JEVU-EB3W-1zNDLS
  LV Write Access        read/write
  LV Creation host, time otusadmin, 2025-05-18 11:29:03 +0000
  LV Status              available
  # open                 0
  LV Size                700.00 MiB
  Current LE             175
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           252:1

  --- Physical volumes ---
  PV Name               /dev/sdf
  PV UUID               kxvbYO-uxOR-PwFg-ImPA-aByZ-rC08-JkKe3S
  PV Status             allocatable
  Total PE / Free PE    255 / 80

  ````

 Видим, что был успешно создан VG на базе PV, в котором создан один логический раздел 'data' объемом 700Мб.


#### 2. Форматирование и монтаж файловой системы

Выполним форматирование созданного раздела /dev/datavg/data и монтаж к директории /mnt/data:

````
root@otusadmin:~# mkfs.ext4 /dev/datavg/data
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 179200 4k blocks and 44832 inodes
Filesystem UUID: 5cab64de-3892-4e82-958e-0a74300647b8
Superblock backups stored on blocks:
        32768, 98304, 163840

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

root@otusadmin:~# mkdir /mnt/data
root@otusadmin:~# mount /dev/datavg/data /mnt/data

````

Проверим монтаж:
````
root@otusadmin:~# df -h
#
/dev/mapper/datavg-data            672M   24K  623M   1% /mnt/data
````

Видим, что раздел /dev/mapper/datavg-data успешно примонтирован к каталогу /mnt/data


#### 3. Расширение файловой системы за счёт нового диска

Создадим дополнительный PV на базе /dev/sdg и подключим его к существующей VG datavg. 
В итоге получим следующую схему:

![](/Lab03_LVM/pic/LVM_2.jpg)

По аналогии создаем PV (Physical Volume) на блочном устройстве /dev/sdg:

````
root@otusadmin:~# pvcreate /dev/sdg
  Physical volume "/dev/sdg" successfully created.
````
И расширяем VG datavg, включив туда созданный PV /dev/sdf:

````
root@otusadmin:~# vgextend datavg /dev/sdg
  Volume group "datavg" successfully extended
````

Проверим состав дисков в VG:

````
root@otusadmin:~# vgdisplay -v datavg | grep 'PV Name'
  PV Name               /dev/sdf
  PV Name               /dev/sdg
````

Видим, что оба диска присутствуют в VG и общий объем VG 2G (1GB + 1GB):

````
root@otusadmin:~# vgs
  VG        #PV #LV #SN Attr   VSize   VFree
  datavg      2   1   0 wz--n-   1.99g <1.31g
````

из которых 700Mb заняты LV /dev/datavg/data. Соответственно, свободное пространство на VG 1,3Gb.

Сделаем так, чтобы весь свободный объем ушел на увеличение LV /data/datavg/data:

````
root@otusadmin:~# lvextend -l+100%FREE /dev/datavg/data
  Size of logical volume datavg/data changed from 700.00 MiB (175 extents) to 1.99 GiB (510 extents).
  Logical volume datavg/data successfully resized.

````

Как видим, система успешно увеличила объем LV data до 2GB.

````
root@otusadmin:~# lvs /dev/datavg/data
  LV   VG     Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data datavg -wi-ao---- 1.99g
````

````
root@otusadmin:~# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
#
sdf                         8:80   0    1G  0 disk
└─datavg-data             252:1    0    2G  0 lvm    /mnt/data
sdg                         8:96   0    1G  0 disk
└─datavg-data             252:1    0    2G  0 lvm    /mnt/data

````


#### 4. Выполнение resize

Несмотря на увеличение объема LV data на данный момент объем FS (File System), а значит и доступный объем для работы с файлами в разделе остался прежним:

````
root@otusadmin:~# df /mnt/data
Filesystem              1K-blocks  Used Available Use% Mounted on
/dev/mapper/datavg-data    687736    24    637536   1% /mnt/data
````

Видно, что объем FS составляет 700Mb.

Для того, чтобы использовать весь объем необходимо выполнить resize LV:

````
root@otusadmin:~# resize2fs /dev/datavg/data
resize2fs 1.47.0 (5-Feb-2023)
Filesystem at /dev/datavg/data is mounted on /mnt/data; on-line resizing required
old_desc_blocks = 1, new_desc_blocks = 1
The filesystem on /dev/datavg/data is now 522240 (4k) blocks long.

````

Проверяем объем FS после ресайза:

````
root@otusadmin:~# df /mnt/data
Filesystem              1K-blocks  Used Available Use% Mounted on
/dev/mapper/datavg-data   2040424    24   1938124   1% /mnt/data

````
Как видим, теперь объем LV /data составялет 2Gb, что и требовалось достигнуть.

#### 5. Проверка корректности работы

Проверим, что созданный логический диск /mnt/data работает корректно и может нормально использоваться для записи/чтения файлов:

Для начала попробуем записать логфайлы в раздел:

````
root@otusadmin:~# cp -r /var/log/* /mnt/data
root@otusadmin:~# ls -l /mnt/data
total 4176
-rw-r--r-- 1 root root  35665 May 18 12:24 alternatives.log
-rw-r----- 1 root root      0 May 18 12:24 apport.log
drwxr-xr-x 2 root root   4096 May 18 12:24 apt
-rw-r----- 1 root root   6673 May 18 12:24 auth.log
-rw-r----- 1 root root  36894 May 18 12:24 auth.log.1
 ###################
-rw------- 1 root root   2280 May 18 12:25 vmware-vmsvc-root.log
-rw------- 1 root root   7560 May 18 12:25 vmware-vmtoolsd-root.log
-rw-r--r-- 1 root root  26880 May 18 12:25 wtmp
root@otusadmin:~#
````

````
Filesystem              1K-blocks   Used Available Use% Mounted on
/dev/mapper/datavg-data   2040424 228552   1709596  12% /mnt/data
````

Как видим, файлы были успешно скопированы, заняв 12% объема LV.

Попробуем полностью заполнить LV:

````
root@otusadmin:~# dd if=/dev/zero of=/mnt/data/test.log bs=1M count=2000 status=progress
1677721600 bytes (1.7 GB, 1.6 GiB) copied, 8 s, 210 MB/s
dd: error writing '/mnt/data/test.log': No space left on device
1756+0 records in
1755+0 records out
1840672768 bytes (1.8 GB, 1.7 GiB) copied, 8.90296 s, 207 MB/s
````


````
root@otusadmin:~# df /mnt/data
Filesystem              1K-blocks    Used Available Use% Mounted on
/dev/mapper/datavg-data   2040424 2026088         0 100% /mnt/data
root@otusadmin:~# ls -l /mnt/data
total 1801712
-rw-r--r-- 1 root root      35665 May 18 12:24 alternatives.log
-rw-r----- 1 root root          0 May 18 12:24 apport.log
#
-rw-r--r-- 1 root root 1840672768 May 18 12:30 test.log
#
-rw-r--r-- 1 root root      26880 May 18 12:25 wtmp
root@otusadmin:~#

````

Как видно, диск полностью заполнинился, использовав весь свой доступный объем - 2Gb. Что говорит о том, что созданный раздел (за которым физически стоит 2 диска) работает корректно. 


#### 6. Работа со снапшотами

Для создания LV для снапшотов подключим еще один физический диск - /dev/sdh, т.к. на данный момент все доступное пространствово выделено под раздел /dev/datavg/data.    

````
root@otusadmin:~# pvcreate /dev/sdh
  Physical volume "/dev/sdh" successfully created.
root@otusadmin:~# vgextend datavg /dev/sdh
  Volume group "datavg" successfully extended
````

````
root@otusadmin:~# vgdisplay -v datavg | grep 'PV Name'
  PV Name               /dev/sdf
  PV Name               /dev/sdg
  PV Name               /dev/sdh
````

Проверим наличие свободного пространства в VG:

````
root@otusadmin:~# vgdisplay datavg
  --- Volume group ---
  VG Name               datavg
  System ID
  Format                lvm2
  Metadata Areas        3
  Metadata Sequence No  5
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                3
  Act PV                3
  VG Size               <2.99 GiB
  PE Size               4.00 MiB
  Total PE              765
  Alloc PE / Size       510 / 1.99 GiB
  Free  PE / Size       255 / 1020.00 MiB
  VG UUID               EhRfTH-ancP-457S-god1-VV13-Kd6B-aM82Ik
````

Видим, что имеется 1Gb свободного пр-ва.

Создадим LV для снапшота раздела /datavg-data объемом в 900Mb:

````
root@otusadmin:~# lvcreate -L 900M -s -n snap_data /dev/mapper/datavg-data
  Logical volume "snap_data" created.
````

Проверим результат действий:

````
root@otusadmin:~# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data      datavg    owi-aos---   1.99g
  snap_data datavg    swi-a-s--- 900.00m      data   0.01
  ubuntu-lv ubuntu-vg -wi-ao---- <19.00g
````

Как видим, создался снапшот snap_data, у которого исходный том 'data', и заполненность 0.01%, т.к. изначально имеем только ссылки на существующие данные, а объем снапшота будет расти по мере изменения данных в исходном разделе. 

Подмонтируем созданный снапшот-раздел к директории 

````
root@otusadmin:~# mkdir /mnt/data-snap
root@otusadmin:~# mount /dev/datavg/snap_data /mnt/data-snap
````

Теперь попробуем удалить некоторые файлы из раздела data:

````
root@otusadmin:~# rm /mnt/data/*.log
````

````
root@otusadmin:~# ls -l /mnt/data
total 2444
drwxr-xr-x 2 root root   4096 May 18 12:24 apt
-rw-r----- 1 root root  36894 May 18 12:24 auth.log.1
-rw-r----- 1 root root      0 May 18 12:24 btmp
drwxr-xr-x 2 root root   4096 May 18 12:24 dist-upgrade
-rw-r----- 1 root root 135896 May 18 12:24 dmesg
-rw-r----- 1 root root 134109 May 18 12:24 dmesg.0
-rw-r--r-- 1 root root      0 May 18 12:24 faillog
drwxr-x--- 4 root root   4096 May 18 12:24 installer
drwxr-xr-x 3 root root   4096 May 18 12:24 journal
-rw-r----- 1 root root 658513 May 18 12:25 kern.log.1
drwxr-xr-x 2 root root   4096 May 18 12:25 landscape
-rw-r--r-- 1 root root 292292 May 18 12:25 lastlog
drwx------ 2 root root  16384 May 18 11:40 lost+found
drwx------ 2 root root   4096 May 18 12:25 private
lrwxrwxrwx 1 root root     39 May 18 12:25 README -> ../../usr/share/doc/systemd/README.logs
-rw-r----- 1 root root 509389 May 18 12:25 syslog
-rw-r----- 1 root root 932796 May 18 12:25 syslog.1
drwxr-xr-x 2 root root   4096 May 18 12:25 sysstat
drwxr-x--- 2 root root   4096 May 18 12:25 unattended-upgrades
-rw-r--r-- 1 root root  26880 May 18 12:25 wtmp

````

проверим объем снапшота:

`````
root@otusadmin:~# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data      datavg    owi-aos---   1.99g
  snap_data datavg    swi-aos--- 900.00m      data   0.02
  ubuntu-lv ubuntu-vg -wi-ao---- <19.00g
`````
Снапшот немного увеличился в размерах (на объем удаленных файлов), а сами удаленные файлы содержатся в снапшоте:

````
root@otusadmin:~# ls -l /mnt/data-snap
total 4176
-rw-r--r-- 1 root root  35665 May 18 12:24 alternatives.log
-rw-r----- 1 root root      0 May 18 12:24 apport.log
drwxr-xr-x 2 root root   4096 May 18 12:24 apt
-rw-r----- 1 root root   6673 May 18 12:24 auth.log
-rw-r----- 1 root root  36894 May 18 12:24 auth.log.1
 ###############
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.1.log
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.2.log
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.3.log
-rw-r--r-- 1 root root    253 May 18 12:25 vmware-network.4.log
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.5.log
-rw-r--r-- 1 root root    253 May 18 12:25 vmware-network.6.log
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.7.log
-rw-r--r-- 1 root root      0 May 18 12:25 vmware-network.8.log
-rw-r--r-- 1 root root    250 May 18 12:25 vmware-network.9.log
-rw-r--r-- 1 root root    195 May 18 12:25 vmware-network.log
-rw------- 1 root root   2494 May 18 12:25 vmware-vmsvc-root.1.log
-rw------- 1 root root   3424 May 18 12:25 vmware-vmsvc-root.2.log
-rw------- 1 root root   2258 May 18 12:25 vmware-vmsvc-root.3.log
-rw------- 1 root root   2280 May 18 12:25 vmware-vmsvc-root.log
-rw------- 1 root root   7560 May 18 12:25 vmware-vmtoolsd-root.log
-rw-r--r-- 1 root root  26880 May 18 12:25 wtmp

````

У нас есть несколько опций для работы с этими даннным - открыть, ручного копирования, а также полное восстановление исходного раздела на момент создания снапшота.

Для последней опции используем опцию --merge, предварительно отмонтировав разделы:

````
root@otusadmin:~# umount /mnt/data-snap
root@otusadmin:~# umount /mnt/data
````

Запускаем процесс мерджа:
````
root@otusadmin:~# lvconvert --merge /dev/datavg/snap_data
````

После завершения снапшот пропадает из разделов: 
````
root@otusadmin:~# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data      datavg    -wi-a-----   1.99g
  ubuntu-lv ubuntu-vg -wi-ao---- <19.00g

````
А на разделе должны восстановится файлы:

````
root@otusadmin:~# mount  /dev/mapper/datavg-data /mnt/data
root@otusadmin:~# ls -l /mnt/dta
ls: cannot access '/mnt/dta': No such file or directory
root@otusadmin:~# ls -l /mnt/data
total 4176
-rw-r--r-- 1 root root  35665 May 18 12:24 alternatives.log
-rw-r----- 1 root root      0 May 18 12:24 apport.log
drwxr-xr-x 2 root root   4096 May 18 12:24 apt
-rw-r----- 1 root root   6673 May 18 12:24 auth.log
##########
-rw------- 1 root root   2258 May 18 12:25 vmware-vmsvc-root.3.log
-rw------- 1 root root   2280 May 18 12:25 vmware-vmsvc-root.log
-rw------- 1 root root   7560 May 18 12:25 vmware-vmtoolsd-root.log
-rw-r--r-- 1 root root  26880 May 18 12:25 wtmp

````

#### 7. Работа LVM-RAID

Выведем диск /dev/sdh из состава VG datavg:

````
root@otusadmin:~# vgreduce datavg /dev/sdh
  Removed "/dev/sdh" from volume group "datavg"
````

Поскольку RAID в LVM работает на уровне LV, то мы можем сделать схему вмда: ввести два диска уже в существующий VG и далее создать там раздел, который будет физически зеркалироваться на два физических раздела.

Вводим два диска /dev/sdh и /dev/sdi в состав VG 'datavg':

`````
root@otusadmin:~# pvcreate /dev/sdi
  Physical volume "/dev/sdi" successfully created.

root@otusadmin:~# vgextend datavg /dev/sdh
  Volume group "datavg" successfully extended
root@otusadmin:~# vgextend datavg /dev/sdi
  Volume group "datavg" successfully extended

`````

И далее создаем логический раздел 'data_m1' объемом 500Мб с зеркалированием (тип RAID 1) на два физических диска:

````
root@otusadmin:~# lvcreate -m 1 datavg -n data_m1 -L 500M /dev/sdh /dev/sdi
  Logical volume "data_m1" created.

````
Проверяем резульат действий:

````
root@otusadmin:~# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data      datavg    -wi-ao----   1.99g
  data_m1   datavg    rwi-a-r--- 500.00m                                    100.00
  ubuntu-lv ubuntu-vg -wi-ao---- <19.00g
````

Видим, что создался раздел 'data_m1' с метрикой 'Sync', указывающая на состяние синхронизированности данных между физическими дисками.

Далее с данным разделом можно работать как с обычным разделом, создав там FS и смонитровав к каталогу:

````
root@otusadmin:~# mkfs.ext4 /dev/datavg/data_m1
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 128000 4k blocks and 128000 inodes
Filesystem UUID: 4e13d8a4-6aef-4081-86d2-c7126d557bfb
Superblock backups stored on blocks:
        32768, 98304

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

root@otusadmin:~# mkdir /mnt/data_m1
root@otusadmin:~# mount /dev/datavg/data_m1 /mnt/data_m1

````

````
root@otusadmin:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              387M  1.6M  386M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   19G  7.0G   11G  40% /
tmpfs                              1.9G     0  1.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  189M  1.7G  11% /boot
tmpfs                              387M   12K  387M   1% /run/user/1000
/dev/mapper/datavg-data            2.0G  224M  1.7G  12% /mnt/data
/dev/mapper/datavg-data_m1         452M   24K  417M   1% /mnt/data_m1

````

Раздел успешно подмонитровался и может использоваться для работы с файлами:

````
root@otusadmin:~# cp -r /var/log/* /mnt/data_m1

````

````
root@otusadmin:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              387M  1.6M  386M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   19G  7.0G   11G  40% /
tmpfs                              1.9G     0  1.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  189M  1.7G  11% /boot
tmpfs                              387M   12K  387M   1% /run/user/1000
/dev/mapper/datavg-data            2.0G  224M  1.7G  12% /mnt/data
/dev/mapper/datavg-data_m1         452M  224M  194M  54% /mnt/data_m1
````

Воспользуемся командой pvs с опциями чтобы посмотреть, как данные реально распределены по физическим томам:

````
root@otusadmin:~# pvs -o pv_name,lv_name,seg_pe_ranges,seg_size_pe,devices
  PV         LV                 PE Ranges        SSize Devices
  /dev/sda3  ubuntu-lv          /dev/sda3:0-4862  4863 /dev/sda3(0)
  /dev/sda3                                       4864
  /dev/sdf   data               /dev/sdf:0-254     255 /dev/sdf(0)
  /dev/sdg   data               /dev/sdg:0-254     255 /dev/sdg(0)
  /dev/sdh   [data_m1_rmeta_0]  /dev/sdh:0-0         1 /dev/sdh(0)
  /dev/sdh   [data_m1_rimage_0] /dev/sdh:1-125     125 /dev/sdh(1)
  /dev/sdh                                         129
  /dev/sdi   [data_m1_rmeta_1]  /dev/sdi:0-0         1 /dev/sdi(0)
  /dev/sdi   [data_m1_rimage_1] /dev/sdi:1-125     125 /dev/sdi(1)
  /dev/sdi                                         129

````

в гипервизоре имитирем отказ диска /dev/sdi, извлекая его, после чего смотрим состояние системы: 

````
root@otusadmin:~# pvs
  WARNING: Couldn't find device with uuid M93WfA-8dif-P4Ug-dUtM-zl2c-c7rN-x4J9iT.
  WARNING: VG datavg is missing PV M93WfA-8dif-P4Ug-dUtM-zl2c-c7rN-x4J9iT (last written to /dev/sdi).
  WARNING: Couldn't find all devices for LV datavg/data_m1_rimage_1 while checking used and assumed devices.
  WARNING: Couldn't find all devices for LV datavg/data_m1_rmeta_1 while checking used and assumed devices.
  PV         VG        Fmt  Attr PSize    PFree
  /dev/sda3  ubuntu-vg lvm2 a--   <38.00g  19.00g
  /dev/sdf   datavg    lvm2 a--  1020.00m      0
  /dev/sdg   datavg    lvm2 a--  1020.00m      0
  /dev/sdh   datavg    lvm2 a--  1020.00m 516.00m
  [unknown]  datavg    lvm2 a-m  1020.00m 516.00m

`````

Видим, что /dev/sdi отсутствует. 

Однако данные в разделе data_m1 не пропали и доступны:

````
root@otusadmin:~# ls -l /mnt/data_m1
total 4216
-rw-r--r-- 1 root root  35665 May 18 14:17 alternatives.log
-rw-r----- 1 root root      0 May 18 14:17 apport.log
drwxr-xr-x 2 root root   4096 May 18 14:17 apt
-rw-r----- 1 root root  10005 May 18 14:17 auth.log
-rw-r----- 1 root root  36894 May 18 14:17 auth.log.1
-rw-r----- 1 root root   3122 May 18 14:17 auth.log.2.gz
-rw-r--r-- 1 root root  61229 May 18 14:17 bootstrap.log
-rw-r----- 1 root root      0 May 18 14:17 btmp
-rw-r----- 1 root root  84436 May 18 14:17 cloud-init.log
-rw-r----- 1 root root   4622 May 18 14:17 cloud-init-output.log
drwxr-xr-x 2 root root   4096 May 18 14:17 dist-upgrade
##########################
-rw-r--r-- 1 root root    195 May 18 14:17 vmware-network.log
-rw------- 1 root root   2494 May 18 14:17 vmware-vmsvc-root.1.log
-rw------- 1 root root   3424 May 18 14:17 vmware-vmsvc-root.2.log
-rw------- 1 root root   2258 May 18 14:17 vmware-vmsvc-root.3.log
-rw------- 1 root root   2280 May 18 14:17 vmware-vmsvc-root.log
-rw------- 1 root root   7560 May 18 14:17 vmware-vmtoolsd-root.log
-rw-r--r-- 1 root root  26880 May 18 14:17 wtmp

````

Т.е. система отработала корректно, зеркалировав данные.


