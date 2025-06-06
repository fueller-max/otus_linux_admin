### Systemd - создание unit-файла

### Цель:

Научиться редактировать существующие и создавать новые unit-файлы

###  Задание:

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).
2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).
3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.


### Решение:

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).

* Создаем файл /etc/default/watchlog, в котором разместим нужные переменные (слово для поиска и путь к лог-файлу):

````
root@otusadmin:~# touch /etc/default/watchlog
root@otusadmin:~# nano /etc/default/watchlog
````

````
  GNU nano 7.2                 /etc/default/watchlog
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ERROR"
LOG=/var/log/watchlog.log
````
 И создаем файл /var/log/watchlog.log с тестовой записью, содержащее искомое слово:
 
````
root@otusadmin:~# cat > /var/log/watchlog.log
ERROR:  something went wrong...
````

* Создаем скрипт, задача которого провести поиск заданного слова в указанном файле и сделать запись в системном журнале в случае, если слово найдено.  Скрипт размещаем в  /opt/watchlog.sh: 

````
cat > /opt/watchlog.sh
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found the word, Master!"
else
exit 0
fi
````

* Делаем данный файл исполняемым:

````
root@otusadmin:~# chmod +x /opt/watchlog.sh
````

* Создаем файл модуля для нашего сервиса:

````
root@otusadmin:~# cat > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
````

В секции [Service] описываем команду на запуск (/etc/default/watchlog) и тип запуска (Type=oneshot), а также EnvironmentFile, где указываем созданный ранее файл с конфигурационными данными.


* Создаем файл модуля для сервиса таймера:
````
root@otusadmin:~# cat > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
````
Данный сервис будет вызвать юинт watchlog.service каждые 30 сек 
Также в сервисе timer в секции [Install] помещаем информацию о цели, в которой он должен запуститься. В нашем случае это multi-user.target.

* Далее запускаем созданный сервис таймера:

```
root@otusadmin:~# systemctl start watchlog.timer
```
* Проверяем, что сервис таймера запустился:

````
root@otusadmin:~# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; preset: ena>
     Active: active (elapsed) since Fri 2025-06-06 08:30:22 UTC; 26s ago
    Trigger: n/a
   Triggers: ● watchlog.service

Jun 06 08:30:22 otusadmin systemd[1]: Started watchlog.timer - Run watchlog sc>
````

Видно, что вызываемый сервис watchlog.service привязан к watchlog.timer и переодически вызывается:

````
root@otusadmin:~# systemctl status watchlog.service
● watchlog.service - My watchlog service
     Loaded: loaded (/etc/systemd/system/watchlog.service; static)
     Active: activating (start) since Fri 2025-06-06 09:36:10 UTC; 1ms ago
TriggeredBy: ● watchlog.timer
   Main PID: 2761 (watchlog.sh)
      Tasks: 1 (limit: 4548)
     Memory: 340.0K (peak: 348.0K)
        CPU: 1ms
     CGroup: /system.slice/watchlog.service
             ├─2761 /bin/bash /opt/watchlog.sh ERROR /var/log/watchlog.log
             └─2762 date

````

Каждый вызов сервиса сопровождается занесением записи в  системный журнал, как и ожидалось:

````
root@otusadmin:~# tail -n 100 /var/log/syslog | grep Master
2025-06-06T09:25:10.435172+00:00 localhost root: Fri Jun  6 09:25:09 AM UTC 2025: I found the word, Master!
2025-06-06T09:31:33.300684+00:00 localhost root: Fri Jun  6 09:31:33 AM UTC 2025: I found the word, Master!
2025-06-06T09:32:09.651593+00:00 localhost root: Fri Jun  6 09:32:09 AM UTC 2025: I found the word, Master!
2025-06-06T09:33:19.672772+00:00 localhost root: Fri Jun  6 09:33:19 AM UTC 2025: I found the word, Master!
2025-06-06T09:34:19.643640+00:00 localhost root: Fri Jun  6 09:34:19 AM UTC 2025: I found the word, Master!
2025-06-06T09:35:01.829661+00:00 localhost root: Fri Jun  6 09:35:01 AM UTC 2025: I found the word, Master!
2025-06-06T09:35:39.684775+00:00 localhost root: Fri Jun  6 09:35:39 AM UTC 2025: I found the word, Master!
2025-06-06T09:36:10.531041+00:00 localhost root: Fri Jun  6 09:36:10 AM UTC 2025: I found the word, Master!
2025-06-06T09:36:49.647342+00:00 localhost root: Fri Jun  6 09:36:49 AM UTC 2025: I found the word, Master!
2025-06-06T09:37:59.677281+00:00 localhost root: Fri Jun  6 09:37:59 AM UTC 2025: I found the word, Master!

````

Видим, что в целом, сервис работает, однако точность времени срабатывания довольно низкая - вызов происходит с точностью порядка 10 сек. Базовая точность таймера у systemd 1 мин, но есть возможность увеличить точность работы вплоть до 1 мс. Для наших целей установим точность работы таймера в 1 сек. Также установим параметр OnBootSec=30 - время первого срабатывания после запуска системы (без этой настройки в конкретной системе наблюдались переодиечские проблемы с незапуском таймера...):

````
[Timer]
#Set the timer accuracy to 1 second instead of the default 1 minute
AccuracySec=1
#Run 30 seconds after boot for the first time
OnBootSec=30
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

````

После этого наблюдаем стабильный вызов с точностью в 1 сек:
````
root@otusadmin:~# tail -n 50 /var/log/syslog | grep Master
2025-06-06T09:55:09.844229+00:00 localhost root: Fri Jun  6 09:55:09 AM UTC 2025: I found the word, Master!
2025-06-06T09:55:40.676418+00:00 localhost root: Fri Jun  6 09:55:40 AM UTC 2025: I found the word, Master!
2025-06-06T09:56:11.667629+00:00 localhost root: Fri Jun  6 09:56:11 AM UTC 2025: I found the word, Master!
2025-06-06T09:56:42.645841+00:00 localhost root: Fri Jun  6 09:56:42 AM UTC 2025: I found the word, Master!
2025-06-06T09:57:13.673891+00:00 localhost root: Fri Jun  6 09:57:13 AM UTC 2025: I found the word, Master!
2025-06-06T09:57:44.644010+00:00 localhost root: Fri Jun  6 09:57:44 AM UTC 2025: I found the word, Master!
2025-06-06T09:58:15.689133+00:00 localhost root: Fri Jun  6 09:58:15 AM UTC 2025: I found the word, Master!
````

2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020)

* Устанавливаем spawn-fcgi (сервис для запуска процессов FastCGI, используемых для ускорения обращения веб-серверов к внешним приложениям), а также все дополнительные сервисы:

````
root@otusadmin:~# apt install spawn-fcgi php php-cgi php-cli  apache2 libapache2-mod-fcgid -y
````

* Создаем файл с настройками для будущего сервиса spawn-fcgi:

````
root@otusadmin:~# mkdir /etc/spawn-fcgi
root@otusadmin:~# cat > /etc/spawn-fcgi/fcgi.conf
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
````

* Создаем файл модуля для сервиса spawn-fcgi:

````
root@otusadmin:~# cat > /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
````

Здесь используем следующие настройки:
 -Запуск после network.target (Это логично для данного сервиса, хотя нужно понимать, что специально этот сервис запускать network.target не будет, так что данная настройка выполняет описательную функцию)
 -тип сервиса Type=simple, что означает мнгновенный старт после запуска, отсутствие форков
 -указываем созданный файл конфигурации в качестве EnvironmentFile
 -KillMode=process означает, что при остановке будет терминирован только основной процесс без дочерних


* Запускаем сервис spawn-fcgi:

````
root@otusadmin:~# systemctl start spawn-fcgi
````
* И убеждаемся, что сервис успешно запущен и работает:
````
root@otusadmin:~# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; preset: enabled)
     Active: active (running) since Fri 2025-06-06 10:23:44 UTC; 4s ago
   Main PID: 12488 (php-cgi)
      Tasks: 33 (limit: 4548)
     Memory: 14.6M (peak: 14.9M)
        CPU: 32ms
     CGroup: /system.slice/spawn-fcgi.service
````

3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

Установим Nginx из репозитория:

````
root@otusadmin:~# apt install nginx -y
````

Создадим два файла конфигурации: nginx-first.conf, nginx-second.conf на базе стандартного, где изменим порт и PID:

````
root@otusadmin:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
root@otusadmin:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf
````

````
root@otusadmin:~# nano /etc/nginx/nginx-first.conf
##
pid /run/nginx-first.pid;
       ##
       server {
                listen 8081;
        }

        ##
        #include /etc/nginx/sites-enabled/*;     
````
````
root@otusadmin:~# nano /etc/nginx/nginx-second.conf
##
pid /run/nginx-second.pid;
    ##
    server {
                listen 8082;

        }

        ##
        #include /etc/nginx/sites-enabled/*;
````


Создаем юнит для сервиса, который может запускать сервис с различной конфигурацией.Используем шаблонизацию (символ @), которая позволяет создать базовый юнит, который можно типизировать при запуске. 

Соответсвенно, места помеченные как %I будут заменены на идентфикатор, указаный после @.
````
root@otusadmin:~# cat > /etc/systemd/system/nginx@.service
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target

````

Запускаем два сервиса с указанием различных файлов конфигурации:

````
root@otusadmin:~# systemctl start nginx@first
root@otusadmin:~# systemctl start nginx@second
````

Проверяем, что два сервиса NGINX запущены и слушают заданные порты:

````
root@otusadmin:~# systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Fri 2025-06-06 11:40:03 UTC; 10min ago
       Docs: man:nginx(8)
    Process: 13957 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, sta>
    Process: 13959 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUC>
   Main PID: 13962 (nginx)
      Tasks: 3 (limit: 4548)
     Memory: 2.3M (peak: 2.5M)
        CPU: 12ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─13962 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             ├─13963 "nginx: worker process"
             └─13964 "nginx: worker process"

Jun 06 11:40:03 otusadmin systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
Jun 06 11:40:03 otusadmin systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.

````
````
root@otusadmin:~# systemctl status nginx@second
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Fri 2025-06-06 11:36:08 UTC; 15min ago
       Docs: man:nginx(8)
    Process: 13831 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, st>
    Process: 13832 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SU>
   Main PID: 13834 (nginx)
      Tasks: 3 (limit: 4548)
     Memory: 2.4M (peak: 2.6M)
        CPU: 11ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─13834 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             ├─13835 "nginx: worker process"
             └─13836 "nginx: worker process"

Jun 06 11:36:08 otusadmin systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
Jun 06 11:36:08 otusadmin systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.

````


````
root@otusadmin:~# ss -tnulp | grep nginx
tcp   LISTEN 0      511                  0.0.0.0:8081       0.0.0.0:*    users:(("nginx",pid=13964,fd=5),("nginx",pid=13963,fd=5),("nginx",pid=13962,fd=5))
tcp   LISTEN 0      511                  0.0.0.0:8082       0.0.0.0:*    users:(("nginx",pid=13836,fd=5),("nginx",pid=13835,fd=5),("nginx",pid=13834,fd=5))

````





















