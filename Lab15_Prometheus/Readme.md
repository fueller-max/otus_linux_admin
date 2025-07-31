# Настройка мониторинга (Prometheus - Grafana)

## Цель

научиться настраивать дашборд

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

* Create a dedicated user and group for Prometheus:

````bash
master@prometheus:~$  sudo groupadd prometheus
master@prometheus:~$  sudo useradd -s /sbin/nologin --system -g prometheus prometheus
````

* Create necessary directories for Prometheus configuration and data

````bash
master@prometheus:~$ sudo mkdir /etc/prometheus
master@prometheus:~$ sudo mkdir /var/lib/prometheus
````

* Set ownership of the data directory

````bash
master@prometheus:~$ sudo chown prometheus:prometheus /var/lib/prometheus
````

* Download the latest stable Prometheus release from the official Prometheus website.
* Extract the downloaded tarbal

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

* Change directory and move binaries

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$
````

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv prometheus /usr/local/bin/
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv promtool /usr/local/bin/
````

* Move  prometheus.yml configuration file to /etc/prometheus/:

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo mv prometheus.yml /etc/prometheus/
````

* Set ownership for the moved files and directories:

````bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown prometheus:prometheus /usr/local/bin/prometheus
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown prometheus:prometheus /usr/local/bin/promtool
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo chown -R prometheus:prometheus /etc/prometheus
````

* Create a systemd service file for Prometheus to manage its lifecycle

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

* Reload systemd to recognize the new service:

```bash
master@prometheus:/tmp/prometheus/prometheus-3.5.0.linux-amd64$ sudo systemctl daemon-reload
```

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

![prometheus](/Lab15_Prometheus/pics/prometheus.jpg)



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