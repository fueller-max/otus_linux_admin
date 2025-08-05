# Настройка мониторинга (Prometheus - Grafana)

## Цель

Научиться устанавливать систему мониторинга Prometheus + Grafana, настраивать дашборд

### Задание

Настроить дашборд с 4-мя графиками

* память;
* процессор;
* диск;
* сеть.

### Решение

#### 1. Установка Prometheus

* Обновляем пакеты

```bash
master@prometheus:~$ sudo apt update && sudo apt upgrade
```

* Создаем user и group для Prometheus:

````bash
master@prometheus:~$  sudo groupadd prometheus
master@prometheus:~$  sudo useradd -s /sbin/nologin --system -g prometheus prometheus
````

* Создаем необходимые директории (данные и конфигурации) для Prometheus 

````bash
master@prometheus:~$ sudo mkdir /etc/prometheus
master@prometheus:~$ sudo mkdir /var/lib/prometheus
````

* Задаем владельца директории

````bash
master@prometheus:~$ sudo chown prometheus:prometheus /var/lib/prometheus
````

* Скачиваем последний релиз prometheus и распаковываем

````bash
master@prometheus:~$ mkdir -p /tmp/prometheus
cd /tmp/prometheus
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
tar xvf prometheus*.tar.gz
prometheus-3.5.0.linux-amd64/
prometheus-3.5.0.linux-amd64/prometheus.yml
prometheus-3.5.0.linux-amd64/prometheus
prometheus-3.5.0.linux-amd64/NOTICE
prometheus-3.5.0.linux-amd64/LICENSE
prometheus-3.5.0.linux-amd64/promtool
````

* Перемещаем в необходимые директории

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$
````

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv prometheus /usr/local/bin/
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv promtool /usr/local/bin/
````

* Перемещаем  prometheus.yml конфигурационный файл в директорию /etc/prometheus/:

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv prometheus.yml /etc/prometheus/
````

* Задаем владельца директорий:

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown prometheus:prometheus /usr/local/bin/prometheus
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown prometheus:prometheus /usr/local/bin/promtool
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown -R prometheus:prometheus /etc/prometheus
````

* Создаем сервис для Prometheus для запуска/управления

````bash
sudo nano /etc/systemd/system/prometheus.service

  [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=prometheus
    Group=prometheus
    Type=simple
    ExecStart=/usr/local/bin/prometheus \
        --config.file /etc/prometheus/prometheus.yml \
        --storage.tsdb.path /var/lib/prometheus/ \
        --web.external-url=http://localhost:9090

    [Install]
    WantedBy=multi-user.target
````

* Перезапускаем демоны, запускаем сервис и разрешаем автозагрузку

```bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo systemctl daemon-reload
```
* Проверям статус сервиса
````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo systemctl start prometheus
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$  sudo systemctl enable prometheus
````

```` bash

master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo systemctl status prometheus
● prometheus.service - Prometheus
     Loaded: loaded (/etc/systemd/system/prometheus.service; enabled; preset: enabled)
     Active: active (running) since Thu 2025-07-31 14:23:29 UTC; 39s ago
   Main PID: 18129 (prometheus)
      Tasks: 8 (limit: 4548)
     Memory: 19.2M (peak: 19.5M)
        CPU: 93ms
     CGroup: /system.slice/prometheus.service
             └─18129 /usr/local/bin/prometheus --config.file /etc/prometheus/prometheus.yml --storage.tsdb.path /var/lib/prometheus/ --w>
````

* Prometheus доступен по ссылке

![prometheus](/Lab15_Prometheus_Grafana/pics/prometheus.jpg)


#### 2. Установка Grafana

Предварительно скачиваем deb пакет Grafana и копируем на сервер.

Далее запускаем установку Grafana.

````bash
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_12.0.0_amd64.deb
sudo dpkg -i grafana-enterprise_12.0.0_amd64.deb
````

````bash
master@prometheus:~$ sudo dpkg -i grafana-enterprise_12.0.0_amd64.deb
[sudo] password for master:
Selecting previously unselected package grafana-enterprise.
(Reading database ... 87749 files and directories currently installed.)
Preparing to unpack grafana-enterprise_12.0.0_amd64.deb ...
Unpacking grafana-enterprise (12.0.0) ...
Setting up grafana-enterprise (12.0.0) ...
info: Selecting UID from range 100 to 999 ...

info: Adding system user `grafana' (UID 111) ...
info: Adding new user `grafana' (UID 111) with group `grafana' ...
info: Not creating home directory `/usr/share/grafana'.
### NOT starting on installation, please execute the following statements to configure grafana to start automatically using systemd
 sudo /bin/systemctl daemon-reload
 sudo /bin/systemctl enable grafana-server
### You can start grafana-server by executing
 sudo /bin/systemctl start grafana-server
````
Проверяем, что Grafana запустилась:

![grafana](/Lab15_Prometheus_Grafana/pics/grafana.jpg)


#### 3. Интеграция Grafana с Prometheus

Для связки Grafana c Prometheus используем в Grafana Prometheus как источник данных. 

![](/Lab15_Prometheus_Grafana/pics/grafana_ds_1.jpg)
![](/Lab15_Prometheus_Grafana/pics/grafana_ds_2.jpg)
![](/Lab15_Prometheus_Grafana/pics/grafana_ds_3.jpg)
![](/Lab15_Prometheus_Grafana/pics/grafana_ds_4.jpg)

Таким образом, базовая связка Prometheus + Grafana настроены. 


#### 4. Настройка Node Exporter на мониторинговом хосте.

Будем мониторить хост в локальной сети. Необходимо установить на нем Node Exporter, который будет отдавать данные в Prometheus.

* Скачиваем и распаковываем Node Exporter на хосте

```bash
master@home-server:~$ wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
master@home-server:~$ tar xzfv node_exporter-1.5.0.linux-amd64.tar.gz
```
* Создаем пользователя, перемещаем бинарник в /usr/local/bin

````bash
master@home-server:~$ sudo useradd -rs /bin/false nodeusr
master@home-server:~$ sudo mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/
````
* Создаем сервис

```bash
master@home-server:~$ sudo nano /etc/systemd/system/node_exporter.service

[Unit]
Description=Node Exporter
After=network.target
[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address="0.0.0.0:9100"
[Install]
WantedBy=multi-user.target
```
* Запускаем сервис

```bash
master@home-server:~$ sudo systemctl daemon-reload
master@home-server:~$ sudo systemctl start node_exporter
master@home-server:~$ sudo systemctl enable node_exporter
````
* Проверяем статус сервиса

````bash
master@home-server:~$ systemctl status node_exporter
● node_exporter.service - Node Exporter
     Loaded: loaded (/etc/systemd/system/node_exporter.service; enabled; preset: enabled)
     Active: active (running) since Tue 2025-08-05 09:37:47 UTC; 1min 21s ago
   Main PID: 1851 (node_exporter)
      Tasks: 5 (limit: 6886)
     Memory: 2.7M (peak: 2.9M)
        CPU: 11ms
     CGroup: /system.slice/node_exporter.service
             └─1851 /usr/local/bin/node_exporter

````

Для того, что Prometheus начал сбор данных с нашего хоста в yml файле прописываем job с указанием IP/порт этого хоста и интервалом опроса данных


````bash
master@prometheus:~$ sudo nano /etc/prometheus/prometheus.yml
````

````bash
  - job_name: "home_server_ubuntu"
    scrape_interval: 5s
    static_configs:
      - targets: ['192.168.40.12:9100']
````

Проверяем, что данные по хосту появились в Prometheus:

![](/Lab15_Prometheus_Grafana/pics/prometheus_home_server.jpg)

Таким образом, на данном этапе у нас есть хост, на котором установлен Node Exporter для  внутреннего сбора и предоставления API, машина c Promethus, которая собирает данные с хоста по данному API.

Далее необходимо организовать графическое представление данных с использованием Grafana.

#### 5. Настройка 

Итоговым получился дашборд, который предоставляет 4 основные метрики монитринга хоста: Ядер CPU, RAM, SSD и Network.

![](/Lab15_Prometheus_Grafana/pics/grafana_dashboard.jpg)

Весь процесс создания борда описывать не будем, т.к. он интуитивно ясен, а опишем запросы для расчета данных:

* загрузка CPU в % по ядру:

```bash
100 - (avg by (instance) (irate(node_cpu_seconds_total{cpu="0",job="home_server_ubuntu",mode="idle"}[5m])) * 100)
```

* Данные по RAM

used Memory:

```bash
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / (1024 * 1024 * 1024)
```
Available Memory:

```bash
node_memory_MemAvailable_bytes / (1024 * 1024 * 1024)
```
Total Memory:

```bash
 node_memory_MemTotal_bytes / (1024 * 1024 * 1024)
```

* Данные по сети

полученные данные через интерфейс

```bash
rate(node_network_receive_bytes_total{device="eno1"}[5m]) / (1024 * 1024)
```
отправленные данные через интерфейс
```bash
rate(node_network_transmit_bytes_total{device="eno1"}[5m]) / (1024 * 1024)
```

* Данные по использованию диска

доступная память по логическому тому:

```bash
node_filesystem_size_bytes{device="/dev/mapper/ubuntu--vg-ubuntu--lv", fstype!="rootfs", mountpoint!=""} / (1024 * 1024 * 1024)
```
использованная память по логическому тому:
```bash
(node_filesystem_size_bytes{device="/dev/mapper/ubuntu--vg-ubuntu--lv", fstype!="rootfs", mountpoint!=""} - node_filesystem_avail_bytes{fstype!="rootfs", mountpoint!=""} ) / (1024 * 1024 * 1024)
```


