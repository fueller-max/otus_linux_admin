# Разворачиваем сетевую лабораторию

## Цель

Научиться менять базовые сетевые настройки в Linux-based системах

### Задание

Теоретическая часть:

* Найти свободные подсети
* Посчитать количество узлов в каждой подсети, включая свободные
* Указать Broadcast-адрес для каждой подсети
* Проверить, нет ли ошибок при разбиении

Практическая часть:

* Соединить офисы в сеть согласно логической схеме и настроить роутинг
* Интернет-трафик со всех серверов должен ходить через inetRouter
* Все сервера должны видеть друг друга (должен проходить ping)
* У всех новых серверов отключить дефолт на NAT (eth0), который vagrant поднимает для связи
* Добавить дополнительные сетевые интерфейсы, если потребуется

### Решение

### 1. Теоретическая часть

* Необходимо построить следующую архитектуру сети:

Схематично схема требуемой сети:

![network_scratch](/Lab19_NetworkLab/pics/network_scratch.jpg)

L3 план сети:

![net_plan](/Lab19_NetworkLab/pics/net_plan_theory.jpg)

 Сеть office1:

* 192.168.2.0/26 - dev
* 192.168.2.64/26 - test servers
* 192.168.2.128/26 - managers
* 192.168.2.192/26 - office hardware

Сеть office2:

* 192.168.1.0/25 - dev
* 192.168.1.128/26 - test servers
* 192.168.1.192/26 - office hardware

Сеть central:

* 192.168.0.0/28 - directors
* 192.168.0.32/28 - office hardware
* 192.168.0.64/26 - wifi
* 192.168.255.8/30 - office 1
* 192.168.255.4/30 - office 2

Проведем рассчет указанных сетей, используя subnet-калькулятор

<https://www.calculator.net/ip-subnet-calculator.html>

Сеть office1:

|  Name | Network  | Netmask  |  N(Usable) |  Hostmin | Hostmax   | Broadcast  |
|---|---|---|---|---|---|---|  
| dev  |  192.168.2.0/26 | 255.255.255.192  | 62 | 192.168.2.1  | 192.168.2.62  |192.168.2.63  |
| test servers   | 192.168.2.64/26  |255.255.255.192   | 62  | 192.168.2.65  |192.168.2.126   | 192.168.2.127 |
| managers  | 192.168.2.128/26  |255.255.255.192 |  62 |  192.168.2.129 | 192.168.2.190  |192.168.2.191   |
| office hardware  | 192.168.2.192/26  |255.255.255.192  |62   | 192.168.2.193  | 192.168.2.254  |192.168.2.255   |

Сеть office2:

|  Name | Network  | Netmask  |  N(Usable) |  Hostmin | Hostmax   | Broadcast  |
|---|---|---|---|---|---|---|  
|dev  | 192.168.1.0/25  | 255.255.255.128  | 126  | 192.168.1.1  |192.168.1.126   | 192.168.1.127  |
|test servers   |192.168.1.128/26  |255.255.255.192   |62  |192.168.1.129 |192.168.1.190 |192.168.1.191|
|office hardware  | 192.168.1.128/26  |255.255.255.192   |62   |192.168.1.193 | 192.168.1.254  |192.168.1.255   |

Сеть central:

|  Name | Network  | Netmask  |  N(Usable) |  Hostmin | Hostmax   | Broadcast  |
|---|---|---|---|---|---|---|  
|directors|192.168.0.0/28|255.255.255.240|14|192.168.0.1|192.168.0.14|192.168.0.15|
|office hardware|192.168.0.32/28|255.255.255.240|14|192.168.0.33|192.168.0.46| 192.168.0.47|
|wifi|192.168.0.64/26|255.255.255.192|62|192.168.0.65|192.168.0.126|192.168.0.127|
|office 1 |192.168.255.8/30|255.255.255.252|2|192.168.255.9|192.168.255.10|192.168.255.11|
|office 2 |192.168.255.4/30|255.255.255.252|2|192.168.255.5|192.168.255.6|192.168.255.7|


Список свободных сетей:

* 192.168.0.16/28
* 192.168.0.48/28
* 192.168.0.128/25
* 192.168.255.64/26
* 192.168.255.32/27
* 192.168.255.16/28



### 2. Практическая часть

Для реализации практической части будем использовать среду EVE-NG (среда для виртуализации сетевого оборудования). В ней соберем основные хосты нашей сети на базе образов Ubuntu.

![eve_ng](/Lab19_NetworkLab/pics/Eve_ng.jpg)


####  2.1 Ручная настройка хостов системы

* Сначала произведем ручную настройку всех хостов для достижения сетевой связности системы. После(во второй части) проведем настройку inetRouter с использованием Ansible.

* Для хостов, выполняющих функции роутеров включаем форвардинга между интерфейсами для IPv4, который по умолчанию в ядре отключен. Изменения проводим в файле /etc/sysctl.conf :

![ip_fwd](/Lab19_NetworkLab/pics/ip_forward_1.jpg)

#### 2.1.1 Настройка InetRouter
 
* Настроим правила iptables для InetRouter, которые необходимы для реализации функции NAT (обеспечение возможности доступна в интернет для хостов внутренней сети), а также защиты самого устройства, т.к. оно является пограничным.

Используем стандартный набор правил, который разрешает форвардинг, доступ по SSH и активрует маскарадинг для внешнего интерфейса, смотрящего в интернет.

````bash
# Allow loopback traffic
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow forwarding of traffic to local network
iptables -A FORWARD -i ens4 -o ens3 -j ACCEPT
iptables -A FORWARD -i ens3 -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow forwarding of traffic to Ansible host
iptables -A FORWARD -i ens5 -o ens3 -j ACCEPT
iptables -A FORWARD -i ens3 -o ens -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow SSH access (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Key  command for Masquerading:
sudo iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE

# Default Policies
sudo iptables -P INPUT DROP        # Drop incoming by default
sudo iptables -P FORWARD DROP      # Drop forwarded by default
sudo iptables -P OUTPUT ACCEPT     # Allow all outgoing by default
````

Настройка вручную (во временное состояние). В следующем разделе будет выполнена автоматизация процесса с помощью Ansible с сохранением правил на постоянно.

Далее настроим адресацию и routes в файле /etc/netplan/50-cloud-init.yaml

![net_plan_inetRouter](/Lab19_NetworkLab/pics/netplan/net_plan_inetRouter.jpg)

Здесь ens3 смотрит в интернет и получает адрес по DHCP. ens4 подключен к Central Router и является шлюзом для внутренней сети. ens5 заготовлен под подключение Ansible.

Для ens4  прописываем адрес в соответствии с IP планом, а также прописываем роут до внутренней сети, используя агрегацию:
````bash
ens4: 192.168.0.0/16
````

т.е. всю внутреннюю сеть собираем в широкую подсеть, куда включены все более мелкие сети. 

Это необходимо для того, чтобы обеспечить т.н. "обратный маршрут" и inet Router понимал, в какой интерфейс отправлять трафик приходящий обратно к хостам сети.

#### 2.1.2 Настройка central Router

Настроим адресацию и routes в файле /etc/netplan/50-cloud-init.yaml

![net_plan_centralRouter](/Lab19_NetworkLab/pics/netplan/net_plan_centralRouter.jpg)

Здесь прописываем адреса для каждого интерфейса (также используя IP план). По аналогии с inet Router прописываем routes до соответствующих сетей (office 1 и offcie 2) также используя агрегацию, но уже более узкую.

Агрегация для centralRouter
````bash
ens3: 192.168.2.0/24 # office 1
ens4: 192.168.1.0/24 # offiсe 2
````

Для интерфейса, который подключен к inet Router прописывает дефолтный маршрут (0.0.0.0/0) в сторону inet Router. Весь "внешний" трафик (прежде всего выход в интернет) будет уходить на inet Router. Также прописываем DNS сервер для реализации разрешения доменных имен.

Далее проведем настройку всех оставшихся хостов(роутеров и серверов) используя аналогичных подход.

#### 2.1.3 Настройка office 1 Router

![net_plan_office1Router](/Lab19_NetworkLab/pics/netplan/net_plan_officeRouter1.jpg)

#### 2.1.4 Настройка office 2 Router

![net_plan_office2Router](/Lab19_NetworkLab/pics/netplan/net_plan_officeRouter2.jpg)

#### 2.1.5 Настройка central Server

![net_plan_centralServer](/Lab19_NetworkLab/pics/netplan/net_plan_centralServer.jpg)

#### 2.1.6 Настройка central Server

![net_plan_centralServer](/Lab19_NetworkLab/pics/netplan/net_plan_centralServer.jpg)


#### 2.1.6 Настройка office 1 Server

![net_plan_office1Server](/Lab19_NetworkLab/pics/netplan/net_plan_office1Server.jpg)

#### 2.1.7 Настройка office 2 Server

![net_plan_office2Server](/Lab19_NetworkLab/pics/netplan/net_plan_office2Server.jpg)


#### 2.1.8 Проверка работы
* После настройки всех хостов проверим, что сеть функционирует, как предполагалось. Проверим, что central Server, office1Server и office1Server имеют доступ в Интернет, а также, что office1Server и office1Server "видят" друг друга.

Проверка доступа в Интернет:
Central Server:
![ping_inetCS](/Lab19_NetworkLab/pics/Pings/centralServerPing.jpg)

Office 1 Server:
![ping_inetof1S](/Lab19_NetworkLab/pics/Pings/office1ServerPing.jpg)

Office 2 Server:
![ping_inetof2S](/Lab19_NetworkLab/pics/Pings/office2ServerPing.jpg)

Ping Office 2 Server с Office 1 Server:
![ping_of2_from_of1](/Lab19_NetworkLab/pics/Pings/ping_offcie2_from_office1.jpg)


Видим, что в целом сеть функционирует, у хостов есть доступ в Интернет по доменным именам, а также обеспечивается внутренняя сетевая связность в сети. 



### 2.2 Автоматизация настройки хоста с помощью Ansible

В качестве задачи автоматизации настроим автоматизацию разворачивания правил iptabes на роутере Inet Router с использованием Ansible.

На Inet router создаем нового пользователя для работы с Ansible и правами админа:

````bash
sudo useradd -m -s /bin/bash ansible
sudo passwd ansible
sudo usermod -aG sudo ansible

```` 
На хосте Ansible генерим ssh ключи и копируем их на Inet router.

Далее настраиваем базовую инфраструктуру на ansible (конфиги, инвентари) и проверяем, что Ansible имеет доступ к Inet outer:

````bash
ssh-keygen -t rsa -b 4096
ssh-copy-id -i ~/.ssh/id_rsa.pub ansible@192.168.50.10
````

![ansible_to_router](/Lab19_NetworkLab/pics/ansible_to_inetRouter.jpg)

Пишем playbook:

![playbook](/Lab19_NetworkLab/pics/ansible/playbookinetRouter.jpg)

Реализация playbook несколько отличается от предложенного подхода в связи с более поздней версии системы. Здесь будем использовать пакет iptables-persistence, который установим, потом скопируем файл с правилами и далее запишем правила на постоянной основе.

Правила IPv4 подготовили на основании предыдущих настроек:

![ipv4_rules](/Lab19_NetworkLab/pics/ansible/rules_v4.jpg)

Запускаем  playbook:

![playbook_fire](/Lab19_NetworkLab/pics/ansible/playbook_accomplished.jpg)

Playbook отработал успешно, проверяем работу.

Перезагружаем inet Router и смотрим, что правила iptables присутсвуют:

![iRouterRules](/Lab19_NetworkLab/pics/ansible/iptables_after_reboot.jpg)

Также проверим наличие интернета на одном из хостов:

![pingAfterRestore](/Lab19_NetworkLab/pics/ansible/ping_after_restore.jpg)

Видим, что доступ в интернет есть, значит правила настроены корректно и сохраняются после перезагрузки системы. 


