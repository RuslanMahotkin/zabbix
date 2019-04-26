#!/bin/bash
# Отправка статистики сервера ElasticSearch на сервер Zabbix

CurlAPI(){
# Запрос к API ElasticSearch

 # Параметры curl:
 #  --max-time		максимальное время операции в секундах;
 #  --no-keepalive	отключение keepalive-сообщений в TCP-соединении;
 #  --silent		отключение индикаторов загрузки и сообщений об ошибках;
 RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://127.0.0.1:9200/$1" | /etc/zabbix/JSON.sh -l 2>/dev/null)
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 [ $? != 0 ] && echo 0 && exit 1
}


# Состояние кластера
CurlAPI '_cluster/health'
# Фильтрация, форматирование данных статистики
OutStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/^((active_primary|active|initializing|relocating|unassigned)_shards|(number_of_data|number_of)_nodes|status)$/ {
 if( $2 == "green"  ) $2 = 0
 if( $2 == "yellow" ) $2 = 1
 if( $2 == "red"    ) $2 = 2
 print "- elasticsearch.cluster." $1, int($2)
}')

# Статистика узла
CurlAPI '_nodes/_local/stats/indices,jvm'
# Фильтрация, форматирование данных статистики
OutStr1=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/(indices.(docs.(count|deleted)|store.size_in_bytes|indexing.(index_total|index_current|delete_total|delete_current)|get.(total|exists_total|missing_total|current)|search.(open_contexts|query_total|query_current|fetch_total|fetch_current)|merges.(current|current_docs|current_size_in_bytes|total|total_docs|total_size_in_bytes)|(refresh|flush).total|warmer.(current|total)|(filter_cache|id_cache|fielddata).memory_size_in_bytes|percolate.(total|current|memory_size_in_bytes|queries)|completion.size_in_bytes|segments.(count|memory_in_bytes)|translog.(operations|size_in_bytes)|suggest.(total|current))|jvm.(mem.(heap_(used|committed)_in_bytes|non_heap_(used|committed)_in_bytes)|threads.count))$/ {
 sub("^nodes.[^.]+.", "", $1)
 print "- elasticsearch.nodes." $1, int($2)
}')

# Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
#  --config		файл конфигурации агента;
#  --host		имя узла сети на сервере Zabbix;
#  --input-file		файл данных('-' - стандартный ввод)
(cat <<EOF
$OutStr
$OutStr1
EOF
) | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
