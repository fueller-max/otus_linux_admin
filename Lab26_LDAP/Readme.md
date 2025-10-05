















Server


```bash
https://www.freeipa.org/page/Quick_Start_Guide

[master@localhost ~]$ hostnamectl set-hostname server.ipa.test

127.0.1.1 server.ipa.test server
192.168.153.164 server.ipa.test server

[master@server ~]$ sudo systemctl stop firewalld
[master@server ~]$ sudo systemctl disable firewalld
[master@server ~]$ sudo setenforce 0

Install FreeIPA server
[master@server ~]$ dnf install freeipa-server

Configure a FreeIPA server
[master@server ~]$ sudo ipa-server-install

he ipa-server-install command was successful

[root@localhost master]# kinit admin
Password for admin@IPA.TEST:

```

Client

````bash
[root@client1 master]# kinit otus-user
kinit: Pre-authentication failed: Invalid argument while getting initial credentials
[root@client1 master]# kinit otus-user
Password for otus-user@IPA.TEST: 
Password expired.  You must change it now.
Enter new password: 
Enter it again: 
[root@client1 master]# su otus-user
sh-5.1$ 
sh-5.1$ whoami
otus-user
````

