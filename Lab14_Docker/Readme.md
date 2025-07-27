# Docker

## Цель

Разобраться с основами docker, с образом, эко системой docker в целом

### Задание

1. Установить Docker на хост машину
2. Установить Docker Compose - как плагин, или как отдельное приложение
3. Создать свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)
4. Определить разницу между контейнером и образом
5. Вывод описать в домашнем задании
6. Можно ли в контейнере собрать ядро?

### Решение

#### 1. Установка Docker на хост машину

В соответствии с инструкциями по установке (<https://docs.docker.com/engine/install/ubuntu/>) выбираем метод установки используя apt репозиторий:

````bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
````

````bash
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
````

````bash
#To install the latest version
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
````

После установки проверяем, что docker установился и пробуем запустить тестовый контейнер "hello world"

````bash
master@docker:~$ sudo docker --version
Docker version 28.3.2, build 578ccf6
````

````bash
master@docker:~$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
e6590344b1a5: Pull complete
Digest: sha256:ec153840d1e635ac434fab5e377081f17e0e15afab27beb3f726c3265039cfff
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

````

Видим, что docker успешно установлен. 

#### 2. Установка Docker Compose - как плагин

Плагин Docker Compose был уже установлен в рамках предыдущего шага. Проверим успешность установки, вызвав версию:

````bash
master@docker:~$ docker compose version
Docker Compose version v2.38.2
````

#### 3.Создать свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)

Создаем папки и необходимые файлы: Dockerfile, index.html.

````bash
master@docker:~$ mkdir docker_test
master@docker:~$ cd docker_test
master@docker:~/docker_test$ touch index.html
master@docker:~/docker_test$ nano index.html
master@docker:~/docker_test$ touch Dockerfile
master@docker:~/docker_test$ nano Dockerfile
````

Заполняем минималистичный Dockerfile для запуска nginx на базе alpine:

````dockerfile
FROM nginx:alpine

# Install Nginx
RUN apk update &&  apk add nginx

# Copy default settings for Nginx
#COPY default.conf /etc/nginx/conf.d/

# Copy custom HTML file to the Nginx directory
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start Nginx when the container starts
CMD ["nginx", "-g", "daemon off;"]

````

В Dockerfile командой COPY копируем наш кастомный html в каталог Nginx`a.
Содержание кастомной html страницы:

````html
<!DOCTYPE html>
<html>
<head>
    <title>Custom Page</title>
</head>
<body>
    <h1>Welcome to My Custom Page!</h1>
    <p>This is a custom page served by Nginx running in a Docker container.</p>
</body>
</html>
````

После этого запускаем build образа из Dockerfile:

````bash
master@docker:~/docker_test$ sudo docker build -t max-custom-nginx_v_1 . 
````

Далее на базе созданного образа запускаем контейнер:

````bash
master@docker:~/docker_test$ sudo docker run -d -p 8080:80 max-custom-nginx_v_1
d375c923ac6a92e2968024de7bfe75936fea4130f9b03a0b46d759244704bc4f
````

Осуществляем проброс 8080 порта хоста к 80 порту контейнера(на котором слушает запущенный nginx в контейнере)

Убеждаемся, что контейнер запущен:

````bash
master@docker:~/docker_test$ sudo docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                     NAMES
d375c923ac6a   max-custom-nginx_v_1   "/docker-entrypoint.…"   17 seconds ago   Up 16 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   upbeat_joliot

````

Проверяем, что страница с нашим контентом загружается:

![html](/Lab14_Docker/pics/Nginx_CustomPage.PNG)

* Опубликуем наш образ на DockerHub.
 Далее действия будем выполнять в системе Windowsб используя Docker Desktop, Git Bash для Windows.

 Создаем образ из Dockerfile: 

````bash
Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker build -t max-custom-nginx_v_1 .
[+] Building 33.8s (8/8) FINISHED
 => [internal] load build definition from Dockerfile                                                                                0.1s
 => => transferring dockerfile: 32B                                                                                                 0.0s
 => [internal] load .dockerignore                                                                                                   0.1s
 => => transferring context: 2B                                                                                                     0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                     0.9s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:d67ea0d64d518b1bb04acde3b00f722ac3e9764b3209a9b0a98924ba35e4b779              24.8s
 => => resolve docker.io/library/nginx:alpine@sha256:d67ea0d64d518b1bb04acde3b00f722ac3e9764b3209a9b0a98924ba35e4b779               0.1s
 => => sha256:fd372c3c84a23422bc07489867f8c2e7e99774680380ccf89c0a269b71b5690f 628B / 628B                                          0.7s
 => => sha256:845b5424415de5f77dd5753cbb7c1be8bd8e44cc81f20f9705783a02f8848317 2.50kB / 2.50kB                                      0.0s
 => => sha256:d6adbc7fd47ec44ff968ea826c84f41d0d5a70a2dce4bd030757f9b7fe9040b8 10.78kB / 10.78kB                                    0.0s
 => => sha256:a5585638209eba93a3af07035d353e512187e9884e402ded45565e264bedb7e1 1.81MB / 1.81MB                                      4.1s
 => => sha256:d67ea0d64d518b1bb04acde3b00f722ac3e9764b3209a9b0a98924ba35e4b779 10.33kB / 10.33kB                                    0.0s
 => => sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8 3.80MB / 3.80MB                                      6.6s
 => => sha256:958a74d6a238e799e7819c7408602b9c5481fa5eda0ee5bcbe1932f685d9d3b9 956B / 956B                                          2.2s
 => => sha256:c1d2dc189e3831ffcb9a19138df97d141f3bd13a13a1513b137cc7ca6e94fa09 405B / 405B                                          2.6s
 => => sha256:828fa206d77bc99972844d67b1a617a841c74f15e71c71e656d1437bd26c15b8 1.21kB / 1.21kB                                      3.5s
 => => sha256:bdaad27fd04a102fe15f473a31a82321c0625a6a3603bd9522bf058eb8a194e2 1.40kB / 1.40kB                                      3.9s
 => => sha256:f23865b38cc69ad61d7a272610d411a4e66c2ed6ab2f374ff8e7f947ecfffb28 16.78MB / 16.78MB                                   22.3s
 => => extracting sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8                                           0.5s
 => => extracting sha256:a5585638209eba93a3af07035d353e512187e9884e402ded45565e264bedb7e1                                           0.3s
 => => extracting sha256:fd372c3c84a23422bc07489867f8c2e7e99774680380ccf89c0a269b71b5690f                                           0.0s
 => => extracting sha256:958a74d6a238e799e7819c7408602b9c5481fa5eda0ee5bcbe1932f685d9d3b9                                           0.0s
 => => extracting sha256:c1d2dc189e3831ffcb9a19138df97d141f3bd13a13a1513b137cc7ca6e94fa09                                           0.0s
 => => extracting sha256:828fa206d77bc99972844d67b1a617a841c74f15e71c71e656d1437bd26c15b8                                           0.0s
 => => extracting sha256:bdaad27fd04a102fe15f473a31a82321c0625a6a3603bd9522bf058eb8a194e2                                           0.0s
 => => extracting sha256:f23865b38cc69ad61d7a272610d411a4e66c2ed6ab2f374ff8e7f947ecfffb28                                           1.4s
 => [internal] load build context                                                                                                   0.1s
 => => transferring context: 261B                                                                                                   0.0s
 => [2/3] RUN apk update &&  apk add nginx                                                                                          7.3s
 => [3/3] COPY index.html /usr/share/nginx/html/index.html                                                                          0.1s
 => exporting to image                                                                                                              0.2s
 => => exporting layers                                                                                                             0.1s
 => => writing image sha256:a183d2c6c9e78d6d09e1b1ddf3ff70a395d9d7387525957e92f9c7a00ee89a00                                        0.0s
 => => naming to docker.io/library/max-custom-nginx_v_1                                                                             0.0s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
````

Проверяем, что образ создался и пушим образ в Docker Hub:

````bash
Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker images
REPOSITORY             TAG       IMAGE ID       CREATED         SIZE
max-custom-nginx_v_1   latest    a183d2c6c9e7   9 minutes ago   55.2MB
hello-world            latest    74cc54e27dc4   6 months ago    10.1kB

Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker tag a183d2c6c9e7 fuellermax/max-custom-nginx_v_1:latest

Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker login
Authenticating with existing credentials...
Login Succeeded

Logging in with your password grants your terminal complete access to your account.
For better security, log in with a limited-privilege personal access token. Learn more at https://docs.docker.com/go/access-tokens/

Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker push fuellermax/max-custom-nginx_v_1:latest
The push refers to repository [docker.io/fuellermax/max-custom-nginx_v_1]
2b1abf220c3b: Pushed
2f0c58c911c8: Pushed
57fb2e22a07a: Pushed
c38bee0b0d28: Pushed
26081059fc81: Pushed
daa8ffa7606a: Pushed
95a6190cfaec: Pushed
430a7aa99a19: Pushed
77a17eed5d29: Pushed
418dccb7d85a: Pushed
latest: digest: sha256:483e9d5e6952189f82d9881264e26793507189f87690d517c180283c9fe7182e size: 2407
````

Образ запушился и доступен по ссылке:

<https://hub.docker.com/repository/docker/fuellermax/max-custom-nginx_v_1/tags>

````bash
docker pull fuellermax/max-custom-nginx_v_1:latest
````

Попробуем запустить запушенный образ с использованием Docker Compose.

Создаем Docker Compose. Указываем образ из репозитория:

````Dockerfile
version: '0.1'
services:
  my-nginx:
    image: fuellermax/max-custom-nginx_v_1:latest
    ports:
      - "8081:80" # Example: Map host port 80 to container port 80
    # Add other configurations as needed, e.g., volumes, environment variables
    # volumes:
    #   - ./data:/app/data
    # environment:

````

Далее запускаем Docker Compose:

````bash
Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker compose up -d
[+] Running 2/2
 - Network lab14_docker_default       Created                                                                                       0.1s
 - Container lab14_docker-my-nginx-1  Started                                                                                       1.2s

Maksim@DESKTOP-U5KCIER MINGW64 /c/otus/LinuxAdmin/otus_linux_admin/Lab14_Docker (main)
$ docker ps
CONTAINER ID   IMAGE                                    COMMAND                  CREATED         STATUS         PORTS                  NA
MES
4c1b715bf150   fuellermax/max-custom-nginx_v_1:latest   "/docker-entrypoint.…"   9 seconds ago   Up 8 seconds   0.0.0.0:8081->80/tcp   la
b14_docker-my-nginx-1
````

Видим, что образ подтянулся и успешно запустился.

![docker_compose](/Lab14_Docker/pics/Nginx_CustomPage_8081.PNG)

#### 4. Определить разницу между контейнером и образом

Образ представляет собой шаблон в котором находятся все необходимые компоненты(библиотеки, зависимости и пр.), в то время как контейнер - это запущенный экземпляр образа. Образ - это шаблон, на основе которого создается контейнер, существует отдельно и не может быть изменен.

#### 5. Вывод описать в домашнем задании

В ходе выполнения задания было сделано следующее:
* Собран кастомный образ Nginx на базе alpine
* На базе образа запущен контейнер и выполнен проборос портов для возможности доступа извне
* Рассмотрен вопрос размещения образов на DockerHub.
* Выполнен запуск контейнера с использованием образа из репозитория с помощью Docker Compose.

Таким образом, изучен базовый функционал работы с Docker.

#### 6. Можно ли в контейнере собрать ядро?

В целом, суть Docker заключается в том, что все контейнеры используют ядро хостовой OS, а не свое. За счет чего и достигается легковесность и быстродействие. Для наличия отдельного ядра необходимо использовать виртуализацию. Тем не менее, существуют способы собрать и запустить контейнер со своим ядром, что требует запуска в привелегированном режиме и монтирования директорий хостовой ОС. Однако, это не является общепринятой и рекомендуемой практикой при использовании контейнерезации.
