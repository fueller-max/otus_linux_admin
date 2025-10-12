# Размещаем свой RPM в своем репозитории

## Цель

Научиться собирать кастомный RPM пакет и размещать его в созданном репозитории

### Задание

1. Создать свой RPM пакет (можно взять свое приложение, либо собрать, например, Apache с определенными опциями).
2. Создать свой репозиторий и разместить там ранее собранный RPM.

### Решение

#### 1. Создание своего RPM пакета (Nginx с дополнительным модулем ngx_broli)

* Устанавливаем Development Tool(компилятор, линкер и пр...) необходимые для сборки:
  
`````bash
[root@localhost master]# yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano

`````

Результат установки:

````bash
Installed:
  annobin-12.98-1.el9.x86_64           cmake-3.26.5-2.el9.x86_64               cmake-data-3.26.5-2.el9.noarch        cmake-filesystem-3.26.5-2.el9.x86_64
  cmake-rpm-macros-3.26.5-2.el9.noarch createrepo_c-0.20.1-4.el9.x86_64        createrepo_c-libs-0.20.1-4.el9.x86_64 debugedit-5.0-11.el9.x86_64
  dwz-0.16-1.el9.x86_64                efi-srpm-macros-6-4.el9.noarch          elfutils-0.193-1.el9.x86_64           fonts-srpm-macros-1:2.0.5-7.el9.1.noarch
  gcc-11.5.0-11.el9.x86_64             gcc-plugin-annobin-11.5.0-11.el9.x86_64 gdb-minimal-16.3-2.el9.x86_64         ghc-srpm-macros-1.5.0-6.el9.noarch
  git-2.47.3-1.el9.x86_64              git-core-2.47.3-1.el9.x86_64            git-core-doc-2.47.3-1.el9.noarch      glibc-devel-2.34-232.el9.x86_64
  glibc-headers-2.34-232.el9.x86_64    go-srpm-macros-3.8.1-1.el9.noarch       kernel-headers-5.14.0-621.el9.x86_64  kernel-srpm-macros-1.0-14.el9.noarch
  libxcrypt-devel-4.4.18-3.el9.x86_64  lua-srpm-macros-1-6.el9.noarch          make-1:4.3-8.el9.x86_64               ocaml-srpm-macros-6-6.el9.noarch
  openblas-srpm-macros-2-11.el9.noarch patch-2.7.6-16.el9.x86_64               perl-Error-1:0.17029-7.el9.noarch     perl-Git-2.47.3-1.el9.noarch
  perl-TermReadKey-2.38-11.el9.x86_64  perl-lib-0.65-483.el9.x86_64            perl-srpm-macros-1-41.el9.noarch      pyproject-srpm-macros-1.16.2-1.el9.noarch
  python-srpm-macros-3.9-54.el9.noarch python3-argcomplete-1.12.0-5.el9.noarch qt5-srpm-macros-5.15.9-1.el9.noarch   redhat-rpm-config-210-1.el9.noarch
  rpm-build-4.16.1.3-39.el9.x86_64     rpmdevtools-9.5-1.el9.noarch            rust-srpm-macros-17-4.el9.noarch      yum-utils-4.3.0-23.el9.noarch
  zstd-1.5.5-1.el9.x86_64

Complete!
````

* Загрузим SRPM пакет Nginx для дальнейшей работы над ним
  
````bash
[root@localhost ~]# mkdir rpm && cd rpm
[root@localhost ~]]# yumdownloader --source nginx
````

Результат загрузки:

```bash
[root@localhost ~]# ll
total 1092
-rw-r--r--. 1 root root 1117721 Oct 12 13:04 nginx-1.20.1-24.el9.src.rpm
```

* Поставим все зависимости для сборки пакета Nginx и создадим дерево каталогов для сборки
  
```bash
[root@localhost ~]$ sudo rpm -Uvh nginx*.src.rpm
[root@localhost ~]# yum-builddep nginx
```

 Дерево rpmbuild директории:

````bash
[root@localhost ~]# ll rpmbuild
total 4
drwxr-xr-x. 2 root root 4096 Oct 12 13:05 SOURCES
drwxr-xr-x. 2 root root   24 Oct 12 13:05 SPECS

````

* Cкачиваем исходный код модуля ngx_brotli, который потребуется при сборке:

```bash
[root@localhost ~]# git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
```

```bash
Receiving objects: 100% (8668/8668), 45.64 MiB | 62.00 KiB/s, done.
Resolving deltas: 100% (5558/5558), done.
Submodule path 'deps/brotli': checked out 'ed738e842d2fbdf2d6459e39267a633c4a9b2f5d'
```

* Переходим в директорию ngx_brotli/deps/brotli и создаем директорию out
  
```bash
[root@localhost ~]# cd ngx_brotli/deps/brotli
[root@localhost brotli]# mkdir out && cd out
```

* Собираем модуль, используя cmake
  
````bash
[root@localhost out]# cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
````

````bash
[root@localhost out]# cmake --build . --config Release -j 2 --target brotlienc
````

* Сборка модуля завершена успешно:

```bash
-- Configuring done (1.5s)
-- Generating done (0.0s)
CMake Warning:
  Manually-specified variables were not used by the project:

    CMAKE_CXX_FLAGS

-- Build files have been written to: /home/otus/rpm/ngx_brotli/deps/brotli/out
```

* Правим spec файл, чтобы Nginx собирался с необходимой опцией: в секцию с параметрами configure добавляем указание на модуль--add-module=/root/ngx_brotli \

```bash
[root@localhost SPECS]# vi nginx.spec
```

````bash
if ! ./configure \
    
    --add-module=/root/ngx_brotli \

````

* Запускаем сборку кастомного rpm модуля nginx c включенным модулем brotli:
  
````bash
[root@localhost SPEC] rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
````

* Сборка заверешена успешно:
  
````bash
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.nVGWBi
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.20.1
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.20.1-24.el9.x86_64
+ RPM_EC=0
++ jobs -p
+ exit 0
````

* Проверяем собраннные пакеты в папке RPMS/x86_64/:
  
````bash
[root@localhost rpmbuild]# ll RPMS/x86_64/
total 1996
-rw-r--r--. 1 root root   36787 Oct 12 13:39 nginx-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root 1029698 Oct 12 13:39 nginx-core-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root  759075 Oct 12 13:39 nginx-mod-devel-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root   19882 Oct 12 13:39 nginx-mod-http-image-filter-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root   31449 Oct 12 13:39 nginx-mod-http-perl-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root   18685 Oct 12 13:39 nginx-mod-http-xslt-filter-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root   54273 Oct 12 13:39 nginx-mod-mail-1.20.1-24.el9.x86_64.rpm
-rw-r--r--. 1 root root   80837 Oct 12 13:39 nginx-mod-stream-1.20.1-24.el9.x86_64.rpm
````

Устанавливаем полученные пакеты локально на систему:

```bash
[root@localhost x86_64]# yum localinstall *.rpm
```

После установки пакетов в конфиге nginx включаем опцию "brotli on" и проверяем конфиг:

```bash
 server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;
        brotli on;
```

````bash
[root@localhost x86_64]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
````

* Запускаем nginx:

````bash
Complete!
[root@localhost x86_64]# systemctl start nginx
[root@localhost x86_64]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sun 2025-10-12 13:44:33 MSK; 3s ago
    Process: 38832 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 38833 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 38834 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 38835 (nginx)
      Tasks: 5 (limit: 22776)
     Memory: 7.2M (peak: 7.8M)
        CPU: 88ms
     CGroup: /system.slice/nginx.service
             ├─38835 "nginx: master process /usr/sbin/nginx"
             ├─38836 "nginx: worker process"
             ├─38837 "nginx: worker process"
             ├─38838 "nginx: worker process"
             └─38839 "nginx: worker process"

Oct 12 13:44:32 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Oct 12 13:44:33 localhost.localdomain nginx[38833]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Oct 12 13:44:33 localhost.localdomain nginx[38833]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Oct 12 13:44:33 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

* Заходим на страницу и видим, что Nginx успешно запустился и отдает страницы:
  
![nginx](/Lab06_RPM_Repo/pics/Nginx.PNG)

#### 2. Создание своего репозитория и размещение там ранее собранного RPM

* Проверяем директорию для статики у nginx:

```bash
[root@localhost /]# ll /usr/share/nginx/html
total 12
-rw-r--r--. 1 root root 3971 Jun 19 12:37 404.html
-rw-r--r--. 1 root root 4020 Jun 19 12:37 50x.html
drwxr-xr-x. 2 root root   27 Oct 12 13:44 icons
lrwxrwxrwx. 1 root root   25 Oct 12 13:39 index.html -> ../../testpage/index.html
-rw-r--r--. 1 root root  368 Jun 19 12:37 nginx-logo.png
lrwxrwxrwx. 1 root root   14 Oct 12 13:39 poweredby.png -> nginx-logo.png
lrwxrwxrwx. 1 root root   37 Oct 12 13:39 system_noindex_logo.png -> ../../pixmaps/system-noindex-logo.png
[root@localhost /]#
```

* Там же создадим каталог repo:
  
 ````bash
 [root@localhost /]# mkdir /usr/share/nginx/html/repo
 ````

* Копируем туда все ранее созданные rpm пакеты:
  
 ````bash
 [root@localhost /]# cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/
 ````

* Инциализируем репозиторий:
  
```bash
[root@localhost /]# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 10 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Preparing sqlite DBs
Pool started (with 5 workers)
Pool finished
```

* В Nginx доступ к листингу каталога. В файле /etc/nginx/nginx.conf в блоке server добавим следующие директивы:
  
```bash
 server {
        
        index index.html index.htm;
        autoindex on;
    }

```

* Проверяем синтаксис конфига:
  
```bash
[root@localhost /]#  nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

* Перезапускаем nginx и проверяем доступ к репозиторию через nginx:
  
```bash
[root@localhost /]# nginx -s reload
```

![repo](/Lab06_RPM_Repo/pics/Nginx_repo.PNG)

* Добавим созданный репозиторий в /etc/yum.repos.d:
  
```bash
[root@localhost /]# cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
```

* Убедимся, что репозиторий подключился:

```bash
[root@localhost /]#  yum repolist enabled | grep otus
otus                          otus-linux
```

* Добавим еще пакет в созданный репозиторий:

```bash
[root@localhost /]# cd /usr/share/nginx/html/repo/
[root@localhost repo]# wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
--2025-10-12 14:46:45--  https://repo.percona.com/yum/percona-release-latest.noarch.rpm
Resolving repo.percona.com (repo.percona.com)... 49.12.125.205, 2a01:4f8:242:5792::2
Connecting to repo.percona.com (repo.percona.com)|49.12.125.205|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 28532 (28K) [application/x-redhat-package-manager]
Saving to: ‘percona-release-latest.noarch.rpm.1’

percona-release-latest.noarch.rpm.1     100%[===============================================================================>]  27.86K  --.-KB/s    in 0.007s

2025-10-12 14:46:52 (3.66 MB/s) - ‘percona-release-latest.noarch.rpm.1’ saved [28532/28532]
```

* Обновляем список пакетов в репозитории:
  
```bash
[root@localhost repo]# createrepo /usr/share/nginx/html/repo/
[root@localhost repo]# yum makecache
```

* Убеждаемся, что пакет появился в нашем репозитории:

````bash
[root@localhost repo]# yum list | grep otus
percona-release.noarch                                1.0-32                               otus
```



