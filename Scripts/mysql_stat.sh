#!/bin/bash
# Отправка статистики сервера MySQL на сервер Zabbix

# Получение строки статистики. Параметры mysqladmin:
#  --silent		'тихий' выход при невозможности установить соединение;
#  --user		MySQL-пользователь соединения;
#  --password		пароль MySQL-пользователя;
#  extended-status	вывод переменных состояния сервера
RespStr=$(/usr/bin/mysqladmin --silent --user=Пользователь_мониторинга --password=Пароль_мониторинга extended-status 2>/dev/null)
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit 1

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk -F'|' '$2~/^ (Com_(delete|insert|replace|select|update)|Connections|Created_tmp_(files|disk_tables|tables)|Key_(reads|read_requests|write_requests|writes)|Max_used_connections|Qcache_(free_memory|hits|inserts|lowmem_prunes|queries_in_cache)|Questions|Slow_queries|Threads_(cached|connected|created|running)|Bytes_(received|sent)|Uptime) +/ {
 gsub(" ", "", $2);
 print "- mysql." $2, int($3)
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
