#!/bin/sh
# Отправка статистики сервера RabbitMQ на сервер Zabbix

CurlAPI(){
# Запрос к API PabbitMQ

 # Параметры curl:
 #  --max-time		максимальное время операции в секундах;
 #  --no-keepalive	отключение keepalive-сообщений в TCP-соединении;
 #  --silent		отключение индикаторов загрузки и сообщений об ошибках;
 #  --ciphers		список используемых наборов шифров;
 #  --insecure		отключение проверки сертификата HTTPS-сервера;
 #  --tlsv1.2		использование TLSv1.2;
 #  --user		'пользователь:пароль' аутентификации на сервере
 RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent --ciphers ecdhe_rsa_aes_128_gcm_sha_256 --insecure --tlsv1.2 --user Пользователь_мониторинга:Пароль_мониторинга "https://127.0.0.1:15672/api/$1" | /etc/zabbix/JSON.sh -l 2>/dev/null)
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 [ $? != 0 ] && echo 0 && exit 1
}


# Строка вывода
OutStr=''
# Разделитель полей во вводимой строке - для построчной обработки
IFS=$'\n'
# В командной строке нет параметров - отправка данных
if [ -z $1 ]; then
 # Общая статистика
 CurlAPI 'overview?columns=message_stats,queue_totals,object_totals'
 # Форматирование данных общей статистики в строке вывода
 for par in $RespStr; do
  OutStr="$OutStr- rabbitmq.${par/	/ }\n"
 done

 # Список очередей
 CurlAPI 'queues?columns=name'
 QueueStr=$RespStr
 # Обработка списка очередей
 for q in $QueueStr; do
  # Имя очереди
  qn=${q#*	}
  # Статистика очереди
  CurlAPI "queues/%2f/$qn?columns=message_stats,memory,messages,messages_ready,messages_unacknowledged,consumers"
  # Форматирование данных статистики очереди в строке вывода
  for par in $RespStr; do
   OutStr="$OutStr- rabbitmq.${par%%	*}[$qn] ${par#*	}\n"
  done
 done

 # Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
 #  --config		файл конфигурации агента;
 #  --host		имя узла сети на сервере Zabbix;
 #  --input-file	файл данных('-' - стандартный ввод)
 echo -en $OutStr | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Возврат статуса сервиса - 'работает'
 echo 1
 exit 0

# Обнаружение очередей
elif [ "$1" = 'queues' ]; then
 # Список очередей
 CurlAPI 'queues?columns=name'
 # Разделитель JSON-списка имен
 es=''
 # Обработка списка очередей
 for q in $RespStr; do
  # JSON-форматирование имени очереди в строке вывода
  OutStr="$OutStr$es{\"{#QUEUENAME}\":\"${q#*	}\"}"
  es=","
 done
 # Вывод списка очередей в формате JSON
 echo -e "{\"data\":[$OutStr]}"
fi
