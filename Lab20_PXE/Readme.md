# PXE

## Цель

Отработать навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

### Задание

1. Настроить загрузку по сети дистрибутива Ubuntu 24
2. Установка должна проходить из HTTP-репозитория.
3. Настроить автоматическую установку c помощью файла user-dat

### Решение

Разворачиванием 


````bash
ansible@ansible:~/PROJECTS/PXE$ ansible-playbook playbooks/provision.yaml

PLAY [Setup PXE Server] ***************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ****************************************************************************************************************************************************************************************************
https://docs.ansible.com/ansible-core/2.18/reference_appendices/interpreter_discovery.html for more information.
ok: [pxeserver]

TASK [Stop ufw service] ***************************************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [Disable ufw service] ************************************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [Update package list] ************************************************************************************************************************************************************************************************
changed: [pxeserver]

TASK [Install dnsmasq] ****************************************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [copy config file] ***************************************************************************************************************************************************************************************************
changed: [pxeserver]

TASK [Create directory] ***************************************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [Download the Ubuntu 24.04 netboot image] ****************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [Extract the tar file to /srv/tftp] **********************************************************************************************************************************************************************************
ok: [pxeserver]

TASK [Restart dnsmasq service] ********************************************************************************************************************************************************************************************
changed: [pxeserver]

PLAY RECAP ****************************************************************************************************************************************************************************************************************
pxeserver                  : ok=10   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
````


````bash
root@pxe:/home/pxe# systemctl status dnsmasq.service
● dnsmasq.service - dnsmasq - A lightweight DHCP and caching DNS server
     Loaded: loaded (/lib/systemd/system/dnsmasq.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-09-15 18:16:47 UTC; 5s ago
    Process: 10586 ExecStartPre=/usr/sbin/dnsmasq --test (code=exited, status=0/SUCCESS)
    Process: 10590 ExecStart=/etc/init.d/dnsmasq systemd-exec (code=exited, status=0/SUCCESS)
    Process: 10616 ExecStartPost=/etc/init.d/dnsmasq systemd-start-resolvconf (code=exited, status=0/SUCCESS)
   Main PID: 10615 (dnsmasq)
      Tasks: 1 (limit: 4550)
     Memory: 1.6M
     CGroup: /system.slice/dnsmasq.service
             └─10615 /usr/sbin/dnsmasq -x /run/dnsmasq/dnsmasq.pid -u dnsmasq -7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new --local-s>

Sep 15 18:16:47 pxe dnsmasq[10586]: dnsmasq: syntax check OK.
Sep 15 18:16:47 pxe dnsmasq[10615]: started, version 2.90 cachesize 150
Sep 15 18:16:47 pxe dnsmasq[10615]: compile time options: IPv6 GNU-getopt DBus no-UBus i18n IDN DHCP DHCPv6 no-Lua TFTP conntrack ipset >
Sep 15 18:16:47 pxe dnsmasq-dhcp[10615]: DHCP, IP range 10.0.0.100 -- 10.0.0.120, lease time 1h
Sep 15 18:16:47 pxe dnsmasq-dhcp[10615]: DHCP, sockets bound exclusively to interface ens37
Sep 15 18:16:47 pxe dnsmasq-tftp[10615]: TFTP root is /srv/tftp/amd64
Sep 15 18:16:47 pxe dnsmasq[10615]: reading /etc/resolv.conf
Sep 15 18:16:47 pxe dnsmasq[10615]: using nameserver 127.0.0.53#53
Sep 15 18:16:47 pxe dnsmasq[10615]: read /etc/hosts - 8 names
Sep 15 18:16:47 pxe systemd[1]: Started dnsmasq - A lightweight DHCP and caching DNS server.

````