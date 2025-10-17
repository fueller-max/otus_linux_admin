



Install uwsgi

```bash
   master@dynweb:~/DYNWEB/python$ sudo apt-get install build-essential python3-dev
   master@dynweb:~/DYNWEB/python$ apt install python3.12-venv
   master@dynweb:~/DYNWEB/python$ python3 -m venv uwsgi_venv

   master@dynweb:~/DYNWEB/python$   source uwsgi_1_venv/bin/activate
   (uwsgi_1_venv) master@dynweb:~/DYNWEB/python$  pip install uwsgi

```

```bash
uwsgi --ini app.ini

```


```` bash
master@dynweb:~/DYNWEB/nodejs$ sudo docker ps
CONTAINER ID   IMAGE                        COMMAND                  CREATED          STATUS          PORTS                                         NAMES
e7fd6ada68a2   nodejs-web                   "docker-entrypoint.s…"   19 minutes ago   Up 19 minutes   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp   nodejs-web-1
fe2f3a6879fe   wordpress:6.1.1-fpm-alpine   "docker-entrypoint.s…"   48 minutes ago   Up 48 minutes   0.0.0.0:9000->9000/tcp, [::]:9000->9000/tcp   wordpress
c384c2acf2c6   mariadb:10.6.4-focal         "docker-entrypoint.s…"   48 minutes ago   Up 48 minutes   3306/tcp, 33060/tcp                           wordpress-db-1
df0786a82404   redis:alpine                 "docker-entrypoint.s…"   22 hours ago     Up 2 hours      0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp   python1-redis-1
master@dynweb:~/DYNWEB/nodejs$

````