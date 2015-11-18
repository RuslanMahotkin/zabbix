#!/bin/bash
# Отправка статистики репликации сервера MySQL на сервер Zabbix

# Получение строки статистики. Параметры mysql:
#  --user		MySQL-пользователь соединения;
#  --password		пароль MySQL-пользователя;
#  --execute		выполнение операторов и выход
RespStr=$(/usr/bin/mysql --user=Пользователь_мониторинга --password=Пароль_мониторинга --execute "SHOW SLAVE STATUS\G" 2>/dev/null)
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 -o ! "$RespStr" ] && echo 0 && exit 1

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk -F':' '$1~/^ +(Slave_(IO|SQL)_Running|Seconds_Behind_Master)$/ {
 gsub(" ", "", $0);
 sub("Yes", 1, $2);
 sub("No", 0, $2);
 sub("NULL", 0, $2);
 print "- mysql.slave." $1, $2
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
