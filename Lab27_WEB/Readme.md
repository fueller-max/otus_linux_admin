# Развертывание веб приложения

## Цель

Получить практические навыки в настройке инфраструктуры с помощью манифестов и конфигураций


### Задание

Собрать стенд:

nginx + python (flask) + php-fpm (wordpress) + js (react)

### Решение

Для реализации стенда будем использовать следующую схему: локальный nginx  + 3 веб-приложения каждое из которых будет работать в своем контейнере.

#### 1. Python (Flask) 

Для реализации работы будем использовать фреймворк Flask в сочетании с UWSGI. UWSGI - отдельный сервер, используемый в качестве слоя между web сервером (в данном случае Nginx) и приложением на python. Такое решение повышает скорость работы приложения за счет исполнения кода python на самом сервере UWSGI.

* Пишем простой скрипт на python app.py используя фреймворк Flask. Также, для небольшого усложнения используем базу Redis для хранения числа - счетчика входов на страницу.

app.py: 

``` python
import time
import redis
from flask import Flask, render_template

app = Flask(__name__)

redis_host = '127.0.1.1'

cache = redis.Redis(host=redis_host, port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)
            


@app.route('/')
def hello():
    count = get_hit_count()
    # Render the index.html template and pass the 'count' variable to it
    return render_template('index.html', count=count)   
```

* Пишем простой html шаблон, который будет рендериться в коде (функция render_template) и отдаваться клиенту при запросе страницы:


``` html
<!DOCTYPE html>
<html>
<head>
    <title>Dynamic Page</title>
</head>
<body>
    <h1>Hello!</h1>
    <p>This page was dynamically rendered by Flask using the Jinja template engine and uWSGI!</p>
    <p>This page have been hit {{ count }} times</p>
</body>
</html> 
```

* Для сохранения данных требуется база. Используем базу Redis, для поднятия базы используем следующий Docker compose: 

```bash
version: '3.8'
services:
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
```


* Устанавливаем UWSGI, предварительно установив dev-пакеты python, а также запускаем UWSGI в отдельном env для лучшей изоляции от системного python.
 

```bash
   master@dynweb:~/DYNWEB/python$ sudo apt-get install build-essential python3-dev
   master@dynweb:~/DYNWEB/python$ apt install python3.12-venv
   master@dynweb:~/DYNWEB/python$ python3 -m venv uwsgi_venv

   master@dynweb:~/DYNWEB/python$   source uwsgi_1_venv/bin/activate
   (uwsgi_1_venv) master@dynweb:~/DYNWEB/python$  pip install uwsgi

```

* Пишем ini файл для UWSGI, в которм описываем параметры запуска и режимы работы сервера.

```bash
[uwsgi]
wsgi-file = /home/master/DYNWEB/python1/app.py

# Define the callable Flask application object
callable = app

# Using a Unix socket for communication with Nginx
socket = /tmp/uWSGI_flaskapp.sock  
chmod-socket = 666

#Used for DEBUG
#http-socket = :3031

# Add best-practice settings for production
master = true
processes = 4
vacuum = true
die-on-term = true
```

* Запускаем uwsgi

```bash
uwsgi --ini app.ini
```

* Для работы с uwsgi используем следующую конфигурацию Nginx:

```bash
# port 8081 Flask app using uWSGI
	server {
         listen 8081;
         server_name localhost;

	 # Pass all requests to uWSGI
         location / {
               include uwsgi_params;                       # Include standard uWSGI parameters
               uwsgi_pass unix:///tmp/uWSGI_flaskapp.sock; # Path to  uWSGI Unix socket
         }
	
	}
```

В location перенаправляем все запросы с порта 8081 на Unix- сокет uWSGI_flaskapp.sock (который описали в ini файле), который используется как пайп для связи с uwsgi сервером.

* Отображаение страницы на порту 8081

![uwsgi](/Lab27_WEB/pics/uWSGI_8081.jpg)

Видим, что связка front web + backend на flask +  uwsgi работает и отдается страница, на котрой также отображается счетчик числа посещений страницы.

#### 2. php-fpm (wordpress)

Для реализации работы будем использовать подход с Fast CGI - современный протокол взаимодействия front web c бэкенд серверами. 

* Для разворачивания бэкенда на wordpress используем Docker compose для развертывания MySQL + WordPress:

```bash
services:
  db:
    # Use a mariadb image which supports both amd64 & arm64 architecture
    image: mariadb:10.6.4-focal
    command: '--default-authentication-plugin=mysql_native_password'
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=somewordpress
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wordpress
      - MYSQL_PASSWORD=wordpress
    expose:
      - 3306
      - 33060

  wordpress:
    image: wordpress:6.1.1-fpm-alpine
    container_name: wordpress
    restart: unless-stopped
    volumes:
      - /var/www/html:/var/www/html
    environment:
      - WORDPRESS_DB_HOST=db
      - WORDPRESS_DB_USER=wordpress
      - WORDPRESS_DB_PASSWORD=wordpress
      - WORDPRESS_DB_NAME=wordpress
    ports:
      - 9000:9000
    depends_on:
      - db
volumes:
  db_data:
```

Важно, что образ wordpress должен поддерживать FPM - FastCGI Process Manager, который обычно запускается на 9000 порту и служит для связи по протоколу Fast CGI. 

Связь между Nginx и backend wordpress будет осуществляться через TCP localhost:9000 

* Соответствущая конфигурация Nginx для работы с Fast CGI: 

```bash
# port 8082 Wordress using FastCGI
	server {

	 listen 8082;
	 server_name localhost;
	
         root /var/www/html;
         index index.php index.html index.htm;

	 location / {
	        try_files $uri $uri/ /index.php?$args;
	   }
         
	 location ~ \.php$ {
	        include fastcgi_params;
		fastcgi_pass localhost:9000;
	        fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	   }
	}
```

* Отображаение страницы на порту 8082

![fast_cgi](/Lab27_WEB/pics/FastCGI_8082.jpg)

Также видим, что связка web ngix + backed на wordpress работает корректно и происходит прокисрование запросов по протоколу FastCGI.

#### 3. js (react)

Для реализации работы будем использовать подход proxy pass - стандартное http проксирование без использования спец. протоколов.

* Пишем простой сервер на js

``` js
    const express = require('express');
    const app = express();
    const port = 3000;

    app.get('/', (req, res) => {
      res.send('Hello from Node.js Server!');
    });

    app.listen(port, () => {
      console.log(`Server listening on port ${port}`);
    });
```
* Файл package.json

``` json
   {
      "name": "my-node-app",
      "version": "1.0.0",
      "description": "A basic Node.js app",
      "main": "server.js",
      "scripts": {
        "start": "node server.js"
      },
      "dependencies": {
        "express": "^4.18.2"
      }
    }
```
* Docker файл для запуска сервера. Сервер запустится в контейнере и будет слушать http запросы на порту 3000. 

``` dockerfile
   FROM node:18-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm install
   COPY . .
   EXPOSE 3000
   CMD ["npm", "start"]
```

* Docker-compose для запуска сервиса на базе контейнера выше  и пробросом порта 3000 на хост.

``` docker-compose
    version: '3.8'
    services:
      web:
        build: .
        ports:
          - "3000:3000"
        volumes:
          - .:/app
          - /app/node_modules
```

* Конфигурация Nginx: 

``` bash
 # port 8083 Node js using proxy pass
	server {
         listen 8083;
         server_name localhost;
     
	 location / {
               proxy_pass http://127.0.1.0:3000; 
               proxy_http_version 1.1;
               proxy_set_header Upgrade $http_upgrade;
               proxy_set_header Connection "upgrade";
               proxy_redirect off;
               proxy_set_header Host $host;
               proxy_set_header X-Real-IP $remote_addr;
               proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
               proxy_set_header X-Forwarded-Host $server_name;
           }
       }
```

* Отображение страницы на порту 8083

![proxey](/Lab27_WEB/pics/Proxy_pass_8083.jpg)

Видим, что также связка связка web ngix + backed на js с использованием proxy_pass работает корректно.





* Список всех running Docker containers:


```` bash
master@dynweb:~/DYNWEB/nodejs$ sudo docker ps
CONTAINER ID   IMAGE                        COMMAND                  CREATED          STATUS          PORTS                                         NAMES
e7fd6ada68a2   nodejs-web                   "docker-entrypoint.s…"   19 minutes ago   Up 19 minutes   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp   nodejs-web-1
fe2f3a6879fe   wordpress:6.1.1-fpm-alpine   "docker-entrypoint.s…"   48 minutes ago   Up 48 minutes   0.0.0.0:9000->9000/tcp, [::]:9000->9000/tcp   wordpress
c384c2acf2c6   mariadb:10.6.4-focal         "docker-entrypoint.s…"   48 minutes ago   Up 48 minutes   3306/tcp, 33060/tcp                           wordpress-db-1
df0786a82404   redis:alpine                 "docker-entrypoint.s…"   22 hours ago     Up 2 hours      0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp   python1-redis-1
master@dynweb:~/DYNWEB/nodejs$

````

Все конфигруационные файлы доступны в директории лабораторной работы.