#!/bin/sh
# Отправка статистики сервера Postfix на сервер Zabbix

# Получение строки статистики. Параметры logtail.sh:
#  -l			полное имя файла журнала
#  -o			полное имя файла смещения
# Параметры pflogsumm:
#  -h			количество строк топа в отчете по хостам; 0 - не
#			создается;
#  -u			количество строк топа в отчете по пользователям; 0 - не
#			создается;
#  --mailq		выполнение команды mailq в конце отчета;
#  --no_bounce_detail, --no_deferral_detail, --no_reject_detail
#			скрытие детальных отчетов;
#  --no_no_msg_size	отключение отчета по сообщениям без размера данных;
#  --no_smtpd_warnings	отключение отчета по SMTPD-предупреждениям;
#  --smtpd_stats	статистика SMTPD-соединений
RespStr=$(sudo /etc/zabbix/logtail.pl -l /var/log/maillog -o /tmp/postfix_stat.dat | /usr/sbin/pflogsumm -h 0 -u 0 --mailq --no_bounce_detail --no_deferral_detail --no_no_msg_size --no_reject_detail --no_smtpd_warnings --smtpd_stats 2>/dev/null)
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk '/^ +[0-9]+[kmg]? +(received|delivered|forwarded|deferred|bounced|rejected|reject warnings|held|discarded|bytes (received|delivered)|senders|recipients|(sending|recipient) hosts\/domains|connections)( +\([0-9]+%\))?$/ {
 if( $2 ~/^(reject|bytes)$/ ) $2 = $2"_"$3
 if( $2 ~/^(sending|recipient)$/ ) $2 = $2"_hosts"
 p = 0
 if( $1 ~/k$/ ) p = 1
 if( $1 ~/m$/ ) p = 2
 if( $1 ~/g$/ ) p = 3
 print "- postfix." $2, int($1) * 1024 ^ p
 }
 BEGIN { par["all"] = 0; par["active"] = 0; par["hold"] = 0; par["size"] = 0 }
 /^[0-9A-F]+[*!]? +[0-9]+/ {
  if( $1 ~/*$/ ) par["active"] += 1
  if( $1 ~/!$/ ) par["hold"] += 1
  par["all"] += 1
  par["size"] += int($2)
 }
 END { for(p in par) print "- postfix.queue." p, par[p] }
' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
