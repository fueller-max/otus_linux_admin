# Практика с SELinux

## Цель

Работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется

### Задание

0. Установать Nginx на rpm based Linux машину

1. Запустить nginx на нестандартном порту 3-мя разными способами:

* переключатели setsebool;
* добавление нестандартного порта в имеющийся тип;
* формирование и установка модуля SELinux.

2. Обеспечить работоспособность приложения при включенном selinux.

* развернуть приложенный стенд <https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems>;
* выяснить причину неработоспособности механизма обновления зоны (см. README);
* предложить решение (или решения) для данной проблемы;
* выбрать одно из решений для реализации, предварительно обосновав выбор;
* реализовать выбранное решение и продемонстрировать его работоспособность.

### Решение

0. Установка Nginx на rpm based Linux машину

Установим Nginx на дистрибутив Alma Linux 9. В конфигруации сразу указываем необходимые нам порты, на которых будет находится Nginx - 4881. Сразу запускаем Nginx.

````bash
yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
````

1. Проверка статуса и запуск Nginx различными способами.

* Проверям статус Nginx после запуска в предыдущем пункте:

````bash
[root@localhost otus]# systemctl status nginx.service
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Sat 2025-06-28 13:50:13 MSK; 1min 17s ago
    Process: 80267 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80268 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 126ms

Jun 28 13:50:12 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jun 28 13:50:13 localhost.localdomain systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Jun 28 13:50:13 localhost.localdomain systemd[1]: nginx.service: Failed with result 'exit-code'.
Jun 28 13:50:13 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.

````

Видим, что Nginx не смог запуститься(статус failed). Из логов также видно, что причина есть осутствие необходимых прав доступа к нестандартному для web сервиса порту - 4881.

Отключаем firewall:

````bash
[root@localhost otus]# systemctl status firewalld
○ firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; preset: enabled)
     Active: inactive (dead) since Sat 2025-06-28 14:01:59 MSK; 2s ago
   Duration: 3w 4d 19h 49min 5.758s
       Docs: man:firewalld(1)
    Process: 847 ExecStart=/usr/sbin/firewalld --nofork --nopid $FIREWALLD_ARGS (code=exited, status=0/SUCCESS)
   Main PID: 847 (code=exited, status=0/SUCCESS)
        CPU: 2.409s

Jun 02 18:12:49 localhost systemd[1]: Starting firewalld - dynamic firewall daemon...
Jun 02 18:12:51 localhost systemd[1]: Started firewalld - dynamic firewall daemon.
Jun 28 14:01:56 localhost.localdomain systemd[1]: Stopping firewalld - dynamic firewall daemon...
Jun 28 14:01:59 localhost.localdomain systemd[1]: firewalld.service: Deactivated successfully.
Jun 28 14:01:59 localhost.localdomain systemd[1]: Stopped firewalld - dynamic firewall daemon.
Jun 28 14:01:59 localhost.localdomain systemd[1]: firewalld.service: Consumed 2.409s CPU time.

````

Проверяем режим работы SELinux:

````bash
[root@localhost otus]# getenforce
Enforcing

````bash
SELinux находится в состоянии Enforcing (принудительный) и обеспечивает защиту системы.

Проверим лог SELinux c поиском по порту 4881. Находим необходимые записи, проверям, что они относятся к Nginx и отмечаем время их возникновения.

````bash
[root@localhost otus]# cat  /var/log/audit/audit.log | grep 4881
type=AVC msg=audit(1751107356.146:694): avc:  denied  { name_bind } for  pid=76123 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=AVC msg=audit(1751107580.250:702): avc:  denied  { name_bind } for  pid=76240 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=AVC msg=audit(1751107813.126:771): avc:  denied  { name_bind } for  pid=80268 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

````

Используем утилиту audit2why, которая анализирует лог-записи и выдает причину возникновения блокировки. 

````bash
[root@localhost otus]# grep 1751107580.250:702 /var/log/audit/audit.log | audit2why
tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly.
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1

````

Утилита подсказывает, что причиной является блокировка NIS (который по дефолту выключен). Вариант решения - разблокировка NIS с помощью соответствующей команды. Возможно не лучший варинат решения, т.к. данный способ может потенциально нести проблемы с ослаблением безопасности в целом.

Проверим работу данной опции:

````bash
[root@localhost otus]# setsebool -P nis_enabled on
[root@localhost otus]# systemctl restart nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:10:20 MSK; 17s ago
    Process: 80497 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80498 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80499 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80500 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 4.1M
        CPU: 200ms
     CGroup: /system.slice/nginx.service
             ├─80500 "nginx: master process /usr/sbin/nginx"
             ├─80501 "nginx: worker process"
             └─80502 "nginx: worker process"

Jun 28 14:10:20 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:10:20 localhost.localdomain nginx[80498]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:10:20 localhost.localdomain nginx[80498]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:10:20 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Видим, что послу активации NIS, Nginx смог запуститья в нормальнои режиме.

![Nginx start page](/Lab11_SELinux/pics/var1_Niginx_OK.PNG)

````bash
[root@localhost otus]# getsebool -a | grep nis_enabled
nis_enabled --> on

````

Отключаем NIS, перезапускаем Ngnix и видим, что он снова не запускается:

````bash
[root@localhost otus]# setsebool -P nis_enabled off

````

````bash
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.

````

2. Следующий поход основан на добавлении нового порта в контестный тип http_port_t, чтобы разрешить приложению прослушивать на нем.

Видим, что стандартные web порты относятся к типу http_port_t:

````bash
[root@localhost otus]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989

````

Добавим наш порт 4881 в конекстный тип http_port_t:

````bash
[root@localhost otus]# semanage port -a -t http_port_t -p tcp 4881

````

Проверим, что порт добавлен в тип:

````bash
[root@localhost otus]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988

````

После этого перезапускаем Nginx и видим, что он запустился без сбоев:

````bash
[root@localhost otus]# systemctl restart nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:27:24 MSK; 5s ago
    Process: 80565 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80566 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80567 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80568 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 2.8M
        CPU: 196ms
     CGroup: /system.slice/nginx.service
             ├─80568 "nginx: master process /usr/sbin/nginx"
             ├─80569 "nginx: worker process"
             └─80570 "nginx: worker process"

Jun 28 14:27:24 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:27:24 localhost.localdomain nginx[80566]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:27:24 localhost.localdomain nginx[80566]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:27:24 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Удаляем порт из контекстного типа, после чего Nginx снова не запускается:

````bash
[root@localhost otus]# semanage port -d -t http_port_t -p tcp 4881
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@localhost otus]# systemctl status nginx
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Sat 2025-06-28 14:28:33 MSK; 7s ago
   Duration: 1min 3.314s
    Process: 80583 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80584 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 104ms

Jun 28 14:28:32 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jun 28 14:28:33 localhost.localdomain systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Jun 28 14:28:33 localhost.localdomain systemd[1]: nginx.service: Failed with result 'exit-code'.
Jun 28 14:28:33 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.

````

3. Запуск Nginx с помощью устанвоки модуля.

Проверяем, что Nginx не запускается на данный момент:

````bash
[root@localhost otus]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@localhost otus]# grep nginx /var/log/audit/audit.log

````

Используя логи + утилиту audit2allow, которая формирует policy-пакет для nginx: 

````bash
[root@localhost otus]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

````

Выполняем и команду и видим, что далее Ngnix запускается в нормальном режиме:

````bash
[root@localhost otus]# semodule -i nginx.pp
[root@localhost otus]# systemctl start nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:32:27 MSK; 5s ago
    Process: 80637 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80638 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80639 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80640 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 2.8M
        CPU: 195ms
     CGroup: /system.slice/nginx.service
             ├─80640 "nginx: master process /usr/sbin/nginx"
             ├─80641 "nginx: worker process"
             └─80642 "nginx: worker process"

Jun 28 14:32:27 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:32:27 localhost.localdomain nginx[80638]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:32:27 localhost.localdomain nginx[80638]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:32:27 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Достоинством метода явялется то, что политка остается постоянной (сохраняется после перезагрузки). 

Удаляем установленнй пакет безопасности для Nginx:

````bash
[root@localhost otus]# semodule -r nginx
libsemanage.semanage_direct_remove_key: Removing last nginx module (no other nginx module exists at another priority).
````

После чего запуск Nginx снова стал невозможен:

````bash
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.

````
2. Part 2

````bash
root@otus:/home/otus# git clone https://github.com/Nickmob/vagrant_selinux_dns_problems.git
Cloning into 'vagrant_selinux_dns_problems'...
remote: Enumerating objects: 32, done.
remote: Counting objects: 100% (32/32), done.
remote: Compressing objects: 100% (21/21), done.
remote: Total 32 (delta 9), reused 29 (delta 9), pack-reused 0 (from 0)
Receiving objects: 100% (32/32), 7.23 KiB | 2.41 MiB/s, done.
Resolving deltas: 100% (9/9), done.
```
