### Размещаем свой RPM в своем репозитории

### Цель:

Научиться собирать кастомный RPM пакет и размещать его в созданном репозитории

###  Задание:

1. Создать свой RPM пакет (можно взять свое приложение, либо собрать, например, 
Apache с определенными опциями). 
2. Создать свой репозиторий и разместить там ранее собранный RPM.


### Решение:

1. Создание своего RPM пакета-  Nginx с опцией -http_v3_module - поддержка HTTP3/QUIC. 


* Устанавливаем Development Tool(компилятор, линкер и пр...) необходимые для сборки:
`````
[otus@localhost ~]$ sudo yum groupinstall "Development Tools"

`````

* Скачиваем исходный код Nginx c сервера:
`````
[otus@localhost ~]$ wget http://nginx.org/download/nginx-1.27.1.tar.gz

`````

* Распаковываем скачанный архив:
````
[otus@localhost ~]$ tar -xzf nginx-1.27.1.tar.gz

[otus@localhost ~]$ cd nginx-1.27.1

````

* The build is configured using the configure command. It defines various aspects of the system, including the methods nginx is allowed to use for connection processing. At the end it creates a Makefile.
````
[otus@localhost nginx-1.27.1]$ ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-threads --with-stream --with-stream_ssl_module --with-http_v3_module
````


````
Configuration summary
  + using threads
  + using system PCRE library
  + using system OpenSSL library
  + using system zlib library

  nginx path prefix: "/etc/nginx"
  nginx binary file: "/usr/sbin/nginx"
  nginx modules path: "/usr/lib64/nginx/modules"
  nginx configuration prefix: "/etc/nginx"
  nginx configuration file: "/etc/nginx/nginx.conf"
  nginx pid file: "/var/run/nginx.pid"
  nginx error log file: "/var/log/nginx/error.log"
  nginx http access log file: "/var/log/nginx/access.log"
  nginx http client request body temporary files: "/var/cache/nginx/client_temp"
  nginx http proxy temporary files: "/var/cache/nginx/proxy_temp"
  nginx http fastcgi temporary files: "/var/cache/nginx/fastcgi_temp"
  nginx http uwsgi temporary files: "/var/cache/nginx/uwsgi_temp"
  nginx http scgi temporary files: "/var/cache/nginx/scgi_temp"

````




################################################################################3

`````
[otus@localhost rpm]$ rpmdev-setuptree

`````


`````
[otus@localhost rpmbuild]$ ll
total 0
drwxr-xr-x. 2 otus otus 6 Jun  3 18:56 BUILD
drwxr-xr-x. 2 otus otus 6 Jun  3 18:56 RPMS
drwxr-xr-x. 2 otus otus 6 Jun  3 18:56 SOURCES
drwxr-xr-x. 2 otus otus 6 Jun  3 18:56 SPECS
drwxr-xr-x. 2 otus otus 6 Jun  3 18:56 SRPMS
`````

````
[otus@localhost rpmbuild]$ rpmdev-newspec rpmbuild/SPECS/pg_redis_pubsub.spec
/usr/bin/rpmdev-newspec: line 302: rpmbuild/SPECS/pg_redis_pubsub.spec: No such file or directory
rpmbuild/SPECS/pg_redis_pubsub.spec created; type minimal, rpm version >= 4.16.

````

