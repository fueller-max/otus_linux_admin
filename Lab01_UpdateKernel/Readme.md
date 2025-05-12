### Обновление ядра системы

### Цель:

Научиться обновлять ядро в ОС Linux

###  Задание:

1. Запустить ВМ c Ubuntu.
2. Обновить ядро ОС на новейшую стабильную версию из mainline-репозитория.


### Решение:

1. [Запуск ВМ c Ubuntu](Readme.md#1-запуск-вм-c-ubuntu)
2. [Обновление ядра ОС на новейшую стабильную версию из mainline-репозитория](Readme.md#2-обновление-ядра-ос-на-новейшую-стабильную-версию-из-mainline-репозитория)


#### 1. Запуск ВМ c Ubuntu

Для запуска системы будем использовать менеджер виртуальных машин VMware.
Установим Ubuntu Server 24.04


![](/Lab01_UpdateKernel/pic/VMware_Ubuntu.jpg)


IP: 192.168.153.138
Login: otus/otus
root: otus
#### 2. Обновление ядра ОС на новейшую стабильную версию из mainline-репозитория

1. Проверяем текущую версию ядра:

````
otus@otusadmin:~$ uname -r
6.8.0-58-generic
````
В репозитории выбираем актуальную стабильную версию. На данный момент 6.14.4

![](/Lab01_UpdateKernel/pic/ver614.jpg)

2. Создаем папку и скачиваем пакеты:

`````
otus@otusadmin:~$ mkdir kernel && cd kernel

otus@otusadmin:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-headers-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb


otus@otusadmin:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-headers-6.14.4-061404_6.14.4-061404.202504251003_all.deb


2025-05-01 13:30:29 (16.0 MB/s) - ‘linux-headers-6.14.4-061404_6.14.4-061404.202504251003_all.deb’ saved [13971460/13971460]

otus@otusadmin:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-image-unsigned-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb


2025-05-01 13:30:38 (21.6 MB/s) - ‘linux-image-unsigned-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb’ saved [15769792/15769792]

otus@otusadmin:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-modules-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb


2025-05-01 13:30:52 (48.5 MB/s) - ‘linux-modules-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb’ saved [159488192/159488192]

`````

3.  Устанавливаем(-i) все скачанные пакеты:
````
otus@otusadmin:~/kernel$ sudo dpkg -i *.deb

````
4. Проверяем, что новые пакеты появлись в /boot (директория ядра системы)

`````
otus@otusadmin:~/kernel$ ls -al /boot
total 185460
drwxr-xr-x  4 root root     4096 May  1 13:33 .
drwxr-xr-x 23 root root     4096 May  1 13:01 ..
-rw-r--r--  1 root root   295497 Apr 25 10:03 config-6.14.4-061404-generic
-rw-r--r--  1 root root   287537 Mar 14 14:25 config-6.8.0-58-generic
drwxr-xr-x  5 root root     4096 May  1 13:33 grub
lrwxrwxrwx  1 root root       32 May  1 13:33 initrd.img -> initrd.img-6.14.4-061404-generic
-rw-r--r--  1 root root 70743742 May  1 13:33 initrd.img-6.14.4-061404-generic
-rw-r--r--  1 root root 68720450 May  1 13:01 initrd.img-6.8.0-58-generic
lrwxrwxrwx  1 root root       27 May  1 13:01 initrd.img.old -> initrd.img-6.8.0-58-generic
drwx------  2 root root    16384 May  1 12:59 lost+found
-rw-------  1 root root  9981345 Apr 25 10:03 System.map-6.14.4-061404-generic
-rw-------  1 root root  9107440 Mar 14 14:25 System.map-6.8.0-58-generic
lrwxrwxrwx  1 root root       29 May  1 13:33 vmlinuz -> vmlinuz-6.14.4-061404-generic
-rw-------  1 root root 15737344 Apr 25 10:03 vmlinuz-6.14.4-061404-generic
-rw-------  1 root root 14989704 Apr 11 16:49 vmlinuz-6.8.0-58-generic
lrwxrwxrwx  1 root root       24 May  1 13:01 vmlinuz.old -> vmlinuz-6.8.0-58-generic

`````
5. Обновляем информацию о новом ядре в конфигурацию загрузчика GRUB:
`````
otus@otusadmin:~/kernel$ sudo update-grub
...
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.14.4-061404-generic
Found initrd image: /boot/initrd.img-6.14.4-061404-generic
Found linux image: /boot/vmlinuz-6.8.0-58-generic
Found initrd image: /boot/initrd.img-6.8.0-58-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
...
`````

6. Устанавливаем автоматическую загрузку с первой доступной системы (обновленного ядра). Предыдущее ядро в системе также должно остаться для целей отката.

`````
otus@otusadmin:~/kernel$ sudo grub-set-default 0

`````

7. Перезапускаем систему.

`````
otus@otusadmin:~/kernel$ sudo reboot

`````


8. После успешной загрузки системы проверяем версию ядра
````
otus@otusadmin:~$ uname -r
6.14.4-061404-generic
````

Как видим, версия ядра соответствует обновленной.

На этом установку нового ядра считаем завершенной.


````
otus@otusadmin:~$ sudo nano /etc/default/grub

````

````

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""


````