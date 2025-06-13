### Пишем скрипт

### Цель:

Написать скрипт на языке Bash

###  Задание:

Написать скрипт для CRON, который раз в час будет формировать письмо и отправлять на заданную почту.


Необходимая информация в письме:

1. Список IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
2. Список запрашиваемых URL (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
3. Ошибки веб-сервера/приложения c момента последнего запуска;
4. Список всех кодов HTTP ответа с указанием их кол-ва с момента последнего запуска скрипта.
5. Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.


### Решение:

### Разработка скрипта для анализа лога: 

Создаем файл с будущим скриптом:
````
otus@otusadmin:~/scripts$ touch web_serv_analytic.sh
````
Сразу делаем файл исполняемым:
````
chmod +x web_serv_analytic.sh
````

* Список IP адресов (с наибольшим кол-вом запросов):

````
ip_addresses=$(echo "$log_data_content" | awk '{print $1}' | sort | uniq -c | sort -n | tail -n 10)
````

* Список запрашиваемых URL (с наибольшим кол-вом запросов):

````
url_regex='(http|https):\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/[^")]*)' 

urls=$(echo "$log_data_content" | grep -Eo "$url_regex" | sort | uniq -c | sort -n | tail -n 10)
````

* Ошибки веб-сервера/приложения:

````
error_regex='(error|warn|crit|alert|emerg)'

errors=$(echo "$log_data_content" | grep -Eo "error_regex" )
````

* Список всех кодов HTTP ответа с указанием их кол-ва

````
http_resp_regex='(HTTP/[0-9].[0-9]" [0-9]{3})'

http_responses=$(echo "$log_data_content" | grep -Eo  "$http_resp_regex" | sort | uniq -c | sort -n | tail -n 10)
````

* Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения

````
lockfile="/tmp/web_serv_analytic.lock"

if ! mkdir "$lockfile" 2>/dev/null; then
    echo "Another instance is still running..."
    exit 1
fi

#######################

rm -rf "$lockfile"
````

* Реализация механизма чтения новых данных с момента последнего вызова

````
new_data_provided=0

if [[ "$num_read_lines" > "$num_lines_storied" ]]; then
    new_data_provided=1
fi


##Process log file content line by line in case new data provided#####################

temp_data_file="/tmp/web_serv_dat.t"
touch "$temp_data_file"

## read the data from lof file line by line from stroied value(prev.call) and actual 
## number of lines

if [ "$new_data_provided" -eq 1 ]; then

sed -n "${num_lines_storied},${num_read_lines}p" "$log_file" > "$temp_data_file"

fi


#update the number of lines
echo "$num_read_lines" > "$prev_numb_of_lines"
````

* Обработка данных, запись в файл и отправка Email

````
data_file_prefix="web_serv_analytic"
date_time_suffix=$(date +'%Y_%m_%d_%H_%M_%S')

data_file="$data_file_prefix"."$date_time_suffix"

if [ "$new_data_provided" -eq 1 ]; then

   str_ip_addr="IP addreses:"
   ip_addr_res="$ip_addresses"
   
   str_URLS="URLs:"
   urls_result="$urls"

   str_HTTP_resp="HTTP responses:"
   HTTP_resp_res="$http_responses"
   
   str_serv_err="Server errors:"
   srv_err_res="$errors" 
  
   data_result=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$str_ip_addr" "$ip_addr_res"\
                           "$str_URLS" "$urls_result" "$str_HTTP_resp" "$HTTP_resp_res"\
                           "$str_serv_err" "$srv_err_res")
   
else
   data_result="No no data has been provided since the last script call"
fi 

   echo "$data_result">>"$data_file"

### Send Email####################################################################
send_email=1

if [ "$send_email" -eq 1 ]; then
  mail -s "Web server log report" otus <<EOF
  $data_result
EOF
fi
````

#### Запуск скрипта переодически 

````
otus@otus2:~/scripts$ crontab -l
# Edit this file to introduce tasks to be run by cron.
#

0 * * * * ~/scripts/web_serv_analytic.sh  ~/scripts/access.log

````



````
otus@otus2:~/scripts$ mail
"/var/mail/otus": 9 messages 9 new
>N   1 otus               Fri Jun 13 14:02  13/416   test
 N   2 otus               Fri Jun 13 14:03  13/416   test
 N   3 otus               Fri Jun 13 14:03  13/416   test
 N   4 otus               Fri Jun 13 15:53  13/486   Web server log report
 N   5 otus               Fri Jun 13 15:54  46/1688  Web server log report
 N   6 otus               Fri Jun 13 16:00  13/486   Web server log report
 N   7 Cron Daemon        Fri Jun 13 16:00  23/935   Cron <otus@otus2> ~/scripts/web_serv_analytic.sh access.log
 N   8 otus               Fri Jun 13 17:00  46/1688  Web server log report
 N   9 Cron Daemon        Fri Jun 13 17:00  22/858   Cron <otus@otus2> ~/scripts/web_serv_analytic.sh  ~/scripts/access.log

````


````

Return-Path: <otus@localhost>
X-Original-To: otus@localhost
Delivered-To: otus@localhost
Received: by localhost.localdomain (Postfix, from userid 1000)
        id A01A24143F; Fri, 13 Jun 2025 17:00:01 +0000 (UTC)
Subject: Web server log report
To: <otus@localhost>
X-Mailer: mail (GNU Mailutils 3.7)
Message-Id: <20250613170001.A01A24143F@localhost.localdomain>
Date: Fri, 13 Jun 2025 17:00:01 +0000 (UTC)
From: otus <otus@localhost>

  IP addreses:
     16 95.165.18.146
     17 217.118.66.161
     20 185.6.8.9
     22 148.251.223.21
     24 62.75.198.172
     31 87.250.233.68
     33 188.43.241.106
     37 212.57.117.19
     39 109.236.252.130
     45 93.158.167.130
URLs:
      4 https://dbadmins.ru/wp-content/themes/llorix-one-lite/css/font-awesome.min.css?ver=4.4.0
      9 http://www.google.com/bot.html
     11 http://www.bing.com/bingbot.htm
     14 https://dbadmins.ru/2016/10/17/%D0%9F%D1%80%D0%BE%D0%B4%D0%BE%D0%BB%D0%B6%D0%B0%D0%B5%D0%BC-%D1%8D%D0%BA%D1%81%D0%BF%D0%B5%D1%80%D0%B8%D0%BC%D0
%B5%D0%BD%D1%82%D1%8B-%D1%81-lacp/
     15 https://dbadmins.ru/2016/10/26/%D0%B8%D0%B7%D0%BC%D0%B5%D0%BD%D0%B5%D0%BD%D0%B8%D0%B5-%D1%81%D0%B5%D1%82%D0%B5%D0%B2%D1%8B%D1%85-%D0%BD%D0%B0%D
1%81%D1%82%D1%80%D0%BE%D0%B5%D0%BA-%D0%B4%D0%BB%D1%8F-oracle-rac/
     20 http://www.domaincrawler.com/dbadmins.ru
     21 http://www.semrush.com/bot.html
     37 http://yandex.com/bots
     73 https://dbadmins.ru/
     87 http://yandex.com/bots yabs01
HTTP responses:
      1 HTTP/1.1" 304
      1 HTTP/1.1" 403
      1 HTTP/1.1" 405
      2 HTTP/1.1" 499
      3 HTTP/1.0" 404


````

````
? 9
Return-Path: <otus@localhost.localdomain>
X-Original-To: otus
Delivered-To: otus@localhost.localdomain
Received: by localhost.localdomain (Postfix, from userid 1000)
        id A31CE4143E; Fri, 13 Jun 2025 17:00:01 +0000 (UTC)
From: root@localhost.localdomain (Cron Daemon)
To: otus@localhost.localdomain
Subject: Cron <otus@otus2> ~/scripts/web_serv_analytic.sh  ~/scripts/access.log
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
X-Cron-Env: <SHELL=/bin/sh>
X-Cron-Env: <HOME=/home/otus>
X-Cron-Env: <PATH=/usr/bin:/bin>
X-Cron-Env: <LOGNAME=otus>
Message-Id: <20250613170001.A31CE4143E@localhost.localdomain>
Date: Fri, 13 Jun 2025 17:00:01 +0000 (UTC)

Starting web server access log file analyzer script...

Web server access log file analyzer script has finished it`s job. All data has been sent. HAVE A NICE DAY!

````

````
otus@otus2:~/scripts$ mail
"/var/mail/otus": 11 messages 11 new
>N   1 otus               Fri Jun 13 14:02  13/416   test
 N   2 otus               Fri Jun 13 14:03  13/416   test
 N   3 otus               Fri Jun 13 14:03  13/416   test
 N   4 otus               Fri Jun 13 15:53  13/486   Web server log report
 N   5 otus               Fri Jun 13 15:54  46/1688  Web server log report
 N   6 otus               Fri Jun 13 16:00  13/486   Web server log report
 N   7 Cron Daemon        Fri Jun 13 16:00  23/935   Cron <otus@otus2> ~/scripts/web_serv_analytic.sh access.log
 N   8 otus               Fri Jun 13 17:00  46/1688  Web server log report
 N   9 Cron Daemon        Fri Jun 13 17:00  22/858   Cron <otus@otus2> ~/scripts/web_serv_analytic.sh  ~/scripts/access.log
 N  10 otus               Fri Jun 13 18:00  13/486   Web server log report
 N  11 Cron Daemon        Fri Jun 13 18:00  22/858   Cron <otus@otus2> ~/scripts/web_serv_analytic.sh  ~/scripts/access.log

````

````
Return-Path: <otus@localhost>
X-Original-To: otus@localhost
Delivered-To: otus@localhost
Received: by localhost.localdomain (Postfix, from userid 1000)
        id BDD864143F; Fri, 13 Jun 2025 18:00:01 +0000 (UTC)
Subject: Web server log report
To: <otus@localhost>
X-Mailer: mail (GNU Mailutils 3.7)
Message-Id: <20250613180001.BDD864143F@localhost.localdomain>
Date: Fri, 13 Jun 2025 18:00:01 +0000 (UTC)
From: otus <otus@localhost>

  No no data has been provided since the last script call

````


