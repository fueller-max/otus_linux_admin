### Практические навыки работы с ZFS

### Цель:

Научится самостоятельно устанавливать ZFS, настраивать пулы, изучить основные возможности ZFS;

###  Задание:

1. Определить алгоритм с наилучшим сжатием:
* определить какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
* создать 4 файловых системы на каждой применить свой алгоритм сжатия;
* для сжатия использовать либо текстовый файл, либо группу файлов.
2. Определить настройки пула.
С помощью команды zfs import собрать pool ZFS. С помощью команды zfs import собрать pool ZFS.
Командами zfs определить настройки:
* размер хранилища;
* тип pool
* значение recordsize;
* какое сжатие используется; 
* какая контрольная сумма используется.
3. Работа со снапшотами:
* скопировать файл из удаленной директории;
* восстановить файл локально. zfs receive;
* найти зашифрованное сообщение в файле secret_message.


### Решение:

1. [Определение алгоритма с наилучшим сжатием](Readme.md#1-определение-алгоритма-с-наилучшим-сжатием)
2. [Определение настроек пула](Readme.md#2-определение-настроек-пула)
3. [Работа со снапшотами](Readme.md#3-работа-со-снапшотами)


#### 1. Определение алгоритма с наилучшим сжатием

Устанавливаем пакет для работы с ZFS:

````
root@otusadmin:~# apt install zfsutils-linux
````

Проверем доступные блочные устройства в системе:

````
otus@otusadmin:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0   40G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0   38G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0   19G  0 lvm  /
sdb                         8:16   0    1G  0 disk
sdc                         8:32   0    1G  0 disk
sdd                         8:48   0    1G  0 disk
sde                         8:64   0    1G  0 disk
sdf                         8:80   0    1G  0 disk
sdg                         8:96   0    1G  0 disk
sdh                         8:112  0    1G  0 disk
sdi                         8:128  0    1G  0 disk
````

Создаем четрые полу тип "mirror" (по типу RAID1):


`````
root@otusadmin:~# zpool create z_pool1 mirror /dev/sdb /dev/sdc
root@otusadmin:~# zpool create z_pool2 mirror /dev/sdd /dev/sde
root@otusadmin:~# zpool create z_pool3 mirror /dev/sdf /dev/sdg
root@otusadmin:~# zpool create z_pool4 mirror /dev/sdh /dev/sdi
root@otusadmin:~# zpool list
`````

Проверяем, что 4 пула созданы, объем каждого пула 1Gb (блочные устройства по 1GB, для RAID1 два диска дабт 1Gb):
`````
NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
z_pool1   960M   114K   960M        -         -     0%     0%  1.00x    ONLINE  -
z_pool2   960M   110K   960M        -         -     0%     0%  1.00x    ONLINE  -
z_pool3   960M   112K   960M        -         -     0%     0%  1.00x    ONLINE  -
z_pool4   960M   134K   960M        -         -     0%     0%  1.00x    ONLINE  -
`````

Настраиваем для каждого из пулов отдельный алгоритм сжатия, который будет использоваться при записи данный в файловую систему:
`````
root@otusadmin:~# zfs set compression=lzjb z_pool1
root@otusadmin:~# zfs set compression=lz4 z_pool2
root@otusadmin:~# zfs set compression=gzip-9 z_pool3
root@otusadmin:~# zfs set compression=zle z_pool4

#####

root@otusadmin:~# zfs get all | grep compression
z_pool1  compression           lzjb                   local
z_pool2  compression           lz4                    local
z_pool3  compression           gzip-9                 local
z_pool4  compression           zle                    local

`````

Качем достаточно объемный файл (40Mb) с текстовой информацией в каждую файловую систему: 

````
root@otusadmin:~# for i in {1..4}; do wget -P /z_pool$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
--2025-05-21 14:55:13--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log

Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41143613 (39M) [text/plain]
Saving to: ‘/z_pool1/pg2600.converter.log’

pg2600.converter.log                    100%[===============================================================================>]  39.24M  1.52MB/s    in 84s

2025-05-21 14:56:38 (477 KB/s) - ‘/z_pool1/pg2600.converter.log’ saved [41143613/41143613]

--2025-05-21 14:56:38--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41143613 (39M) [text/plain]
Saving to: ‘/z_pool2/pg2600.converter.log’

pg2600.converter.log                    100%[===============================================================================>]  39.24M   441KB/s    in 93s

2025-05-21 14:58:12 (431 KB/s) - ‘/z_pool2/pg2600.converter.log’ saved [41143613/41143613]

--2025-05-21 14:58:12--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41143613 (39M) [text/plain]
Saving to: ‘/z_pool3/pg2600.converter.log’

pg2600.converter.log                    100%[===============================================================================>]  39.24M  1.47MB/s    in 57s

2025-05-21 14:59:11 (700 KB/s) - ‘/z_pool3/pg2600.converter.log’ saved [41143613/41143613]

--2025-05-21 14:59:11--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41143613 (39M) [text/plain]
Saving to: ‘/z_pool4/pg2600.converter.log’

pg2600.converter.log                    100%[===============================================================================>]  39.24M   661KB/s    in 66s

2025-05-21 15:00:17 (613 KB/s) - ‘/z_pool4/pg2600.converter.log’ saved [41143613/41143613]
````

Смотрим кол-во занятого простанства в каждом из пулов:

````
root@otusadmin:~# ls -l /z_pool*
/z_pool1:
total 22101
-rw-r--r-- 1 root root 41143613 May  2 07:31 pg2600.converter.log

/z_pool2:
total 18009
-rw-r--r-- 1 root root 41143613 May  2 07:31 pg2600.converter.log

/z_pool3:
total 10967
-rw-r--r-- 1 root root 41143613 May  2 07:31 pg2600.converter.log

/z_pool4:
total 40220
-rw-r--r-- 1 root root 41143613 May  2 07:31 pg2600.converter.log
````

Видим, что наиманьший занятый объем у 3 систему, где используется алгоритм сжатия  gzip-9.

````
root@otusadmin:~# zfs list
NAME      USED  AVAIL  REFER  MOUNTPOINT
z_pool1  21.7M   810M  21.6M  /z_pool1
z_pool2  17.7M   814M  17.6M  /z_pool2
z_pool3  10.9M   821M  10.7M  /z_pool3
z_pool4  39.4M   793M  39.3M  /z_pool4
````

Проверим степень компрессии по данным системы:
````
root@otusadmin:~# zfs get all | grep compressratio | grep -v ref
z_pool1  compressratio         1.81x                  -
z_pool2  compressratio         2.23x                  -
z_pool3  compressratio         3.65x                  -
z_pool4  compressratio         1.00x                  -
````

Видим, что 3 пул имеет наивысшую степень равную 3.65x. При этом алгоритм zle в данном случае не дал никакого сжатия данных и объем данных никак не уменьшился при записи.

Причина такого поведения в том, что gzip-9 - это алгоритм общего назаначения, показывающий хорошие результаты по компрессии для любого типа данныз, однако имеет сниженную скорость работы. При этом zle - это алгоритм, который спроектирован на наборы данных с большим кол-вом нулей внутри. При этом zle самый быстрый.

Таким образом, при выборе алгоритма сжатия необходимо учитывать актальный тип данных, а также требования к скорости работы.  


#### 2. Определение настроек пула

Скачиваем архив по предложенной ссылке:

````
root@otusadmin:~# wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'

--2025-05-21 15:07:33--  https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download
Resolving drive.usercontent.google.com (drive.usercontent.google.com)... 64.233.164.132, 2a00:1450:4010:c07::84
Connecting to drive.usercontent.google.com (drive.usercontent.google.com)|64.233.164.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6.9M) [application/octet-stream]
Saving to: ‘archive.tar.gz’

archive.tar.gz                          100%[===============================================================================>]   6.94M  1.77MB/s    in 4.3s

2025-05-21 15:07:47 (1.60 MB/s) - ‘archive.tar.gz’ saved [7275140/7275140
````

Разархивируем скачанный арихв:

````
root@otusadmin:~# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
````

Проверяем директории:

`````
root@otusadmin:~# ls -l ~/zpoolexport
total 1024008
-rw-r--r-- 1 root root 524288000 May 15  2020 filea
-rw-r--r-- 1 root root 524288000 May 15  2020 fileb
`````

Далее, используя команду zpool import, делаем импорт пула из директории zpoolexport:

`````
root@otusadmin:~# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
`````

Используя команду status проверям результат импорта:

`````
root@otusadmin:~# zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0
`````
Видим, что пул успешно симпортировался, имеет тип RAID1 (в контексте zfs - mirror-0).


Далее, используя команду get all можем вывести подробную информацию по данному пулу:

`````
root@otusadmin:~# zfs get all otus
NAME  PROPERTY              VALUE                  SOURCE
otus  type                  filesystem             -
otus  creation              Fri May 15  4:00 2020  -
otus  used                  2.04M                  -
otus  available             350M                   -
otus  referenced            24K                    -
otus  compressratio         1.00x                  -
otus  mounted               yes                    -
otus  quota                 none                   default
otus  reservation           none                   default
otus  recordsize            128K                   local
otus  mountpoint            /otus                  default
otus  sharenfs              off                    default
otus  checksum              sha256                 local
otus  compression           zle                    local
otus  atime                 on                     default
otus  devices               on                     default
otus  exec                  on                     default
otus  setuid                on                     default
otus  readonly              off                    default
otus  zoned                 off                    default
otus  snapdir               hidden                 default
otus  aclmode               discard                default
otus  aclinherit            restricted             default
otus  createtxg             1                      -
otus  canmount              on                     default
otus  xattr                 on                     default
otus  copies                1                      default
otus  version               5                      -
otus  utf8only              off                    -
otus  normalization         none                   -
otus  casesensitivity       sensitive              -
otus  vscan                 off                    default
otus  nbmand                off                    default
otus  sharesmb              off                    default
otus  refquota              none                   default
otus  refreservation        none                   default
otus  guid                  14592242904030363272   -
otus  primarycache          all                    default
otus  secondarycache        all                    default
otus  usedbysnapshots       0B                     -
otus  usedbydataset         24K                    -
otus  usedbychildren        2.01M                  -
otus  usedbyrefreservation  0B                     -
otus  logbias               latency                default
otus  objsetid              54                     -
otus  dedup                 off                    default
otus  mlslabel              none                   default
otus  sync                  standard               default
otus  dnodesize             legacy                 default
otus  refcompressratio      1.00x                  -
otus  written               24K                    -
otus  logicalused           1020K                  -
otus  logicalreferenced     12K                    -
otus  volmode               default                default
otus  filesystem_limit      none                   default
otus  snapshot_limit        none                   default
otus  filesystem_count      none                   default
otus  snapshot_count        none                   default
otus  snapdev               hidden                 default
otus  acltype               off                    default
otus  context               none                   default
otus  fscontext             none                   default
otus  defcontext            none                   default
otus  rootcontext           none                   default
otus  relatime              on                     default
otus  redundant_metadata    all                    default
otus  overlay               on                     default
otus  encryption            off                    default
otus  keylocation           none                   default
otus  keyformat             none                   default
otus  pbkdf2iters           0                      default
otus  special_small_blocks  0                      default
`````



#### 3. Работа со снапшотами

Скачиваем файл по предложенной ссылке:

````
root@otusadmin:~# wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
[1] 3280
root@otusadmin:~#
Redirecting output to ‘wget-log’.

[1]+  Done                   
````

Используя команду receive принимаем файловую систему в точку монтирования /otus/test:

````
root@otusadmin:~# zfs receive otus/test@today < otus_task2.file
````

Проверяем результат копирования файловой системы и монитрования:

````
root@otusadmin:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              387M  1.6M  386M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv  9.8G  5.3G  4.0G  57% /
tmpfs                              1.9G     0  1.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          1.8G   96M  1.6G   6% /boot
tmpfs                              387M   12K  387M   1% /run/user/1000
z_pool1                            832M   22M  811M   3% /z_pool1
z_pool2                            832M   18M  815M   3% /z_pool2
z_pool3                            832M   11M  822M   2% /z_pool3
z_pool4                            832M   40M  793M   5% /z_pool4
otus                               348M  128K  347M   1% /otus
otus/hometask2                     349M  2.0M  347M   1% /otus/hometask2
otus/test                          350M  2.9M  347M   1% /otus/test
````

Видим, что файловая система успешно скопировалась  и смонтировалась к каталогу otus/test.

Далее, можем работать с ней как обычно, выполнив поиск файла "secret_message":

````
root@otusadmin:~# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
````

и прочитав его содержимое:
`````
root@otusadmin:~# cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/

`````