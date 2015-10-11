#!/bin/bash
# Отправка статистики сервера Php-fpm на сервер Zabbix

# Получение строки статистики. Параметры curl:
#  --max-time		максимальное время операции в секундах;
#  --no-keepalive	отключение keepalive-сообщений в TCP-соединении;
#  --silent		отключение индикаторов загрузки и сообщений об ошибках;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`/ps")
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk -F: '$1~/^(accepted conn|listen queue|max listen queue|listen queue len|(idle|active|total|max active) processes|max children reached|slow requests)$/ {
 gsub(" ", "_", $1);
 print "- php-fpm." $1, int($2)
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
