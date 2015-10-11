# Отправка статистики сервера RabbitMQ на сервер Zabbix


function RabbitMQAPI($Query){
# Запрос к API PabbitMQ. Параметры: 1 - строка параметров запроса API

 # Объект Uri API PabbitMQ
 $uri = New-Object System.Uri("https://127.0.0.1:15672/api/$Query");

 # Предотвращение преобразования '%2f' в символ '/'
 # Инициализация объекта Uri
 $uri.PathAndQuery | Out-Null
 $flagsField = $uri.GetType().GetField("m_Flags", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)
 # remove flags Flags.PathNotCanonical and Flags.QueryNotCanonical
 $flagsField.SetValue($uri, [UInt64]([UInt64]$flagsField.GetValue($uri) -band (-bnot 0x30)))

 $RespStr = $wc.DownloadString($uri) | ConvertFrom-Json
 # Выполнение запроса успешно - возврат строки результата
 if( $? ){ return $RespStr }
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 Write-Host 0
 # Выход из сценария
 exit 1
}


# Кодировка вывода - кодировка консоли
$OutputEncoding = [Console]::OutputEncoding
# Отключение проверки сертификата сервера
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# Вебклиент для получения данных идентифицируемых по URI ресурсов
$wc = New-Object System.Net.WebClient
# Данные аутентификации
$wc.Credentials = New-Object System.Net.NetworkCredential('Пользователь_мониторинга', 'Пароль_мониторинга')

# Получение строки списка очередей
$QueuesStr = RabbitMQAPI 'queues?columns=name'

# Есть аргумент командной строки определения очередей
if( $args[0] -and $args[0] -eq 'queues' ){
 # Трансляция строки списка очередей в формат JSON
 $QueuesStr = $QueuesStr.name -split '`n' -join '"},{"{#QUEUENAME}":"'
 if( $QueuesStr ){ $QueuesStr = "{`"{#QUEUENAME}`":`"" + $QueuesStr + "`"}" }
 $QueuesStr = "{`"data`":[" + $QueuesStr + "]}"
 # Вывод JSON-списка очередей
 Write-Host -NoNewLine $QueuesStr

# Отправка данных
}else{
 # Строка вывода
 $OutStr = ''
 # Общая статистика
 $Overview = RabbitMQAPI 'overview?columns=message_stats,queue_totals,object_totals'
 # Обработка требуемых параметров общей статистики
 foreach($ParName in 'message_stats.ack_details.rate', 'message_stats.ack',
  'message_stats.deliver_get_details.rate', 'message_stats.deliver_get',
  'message_stats.get_details.rate', 'message_stats.get',
  'message_stats.publish_details.rate', 'message_stats.publish',
  'object_totals.channels', 'object_totals.connections',
  'object_totals.consumers', 'object_totals.exchanges', 'object_totals.queues',
  'queue_totals.messages', 'queue_totals.messages_ready',
  'queue_totals.messages_unacknowledged'){
  # Значение параметра - изначально корневой переменной
  $ParValue = $Overview
  # Получение значения параметра
  foreach($i in $ParName.Split('.')){ $ParValue = $ParValue.$i }
  # Параметр не определен - инициализация нулевым значением
  if($ParValue -eq $null){ $ParValue = 0 }
  # Вывод имени и значения параметра в формате zabbix_sender
  $OutStr += '- rabbitmq.' + $ParName + ' ' + $ParValue + "`n"
 }

 # Обработка списка очередей
 foreach($Queue in $QueuesStr.name.Split('`n')){
  # Строка запроса статистики очереди
  $QueueQueryStr = 'queues/%2f/' + $Queue + '?columns=message_stats,memory,messages,messages_ready,messages_unacknowledged,consumers'
   # Статистика очереди
  $QueueStat = RabbitMQAPI "$QueueQueryStr"
  # Обработка требуемых параметров статистики очереди
  foreach($ParName in 'consumers', 'memory', 'messages', 'messages_unacknowledged', 'messages_ready'){
   # Значение параметра
   $ParValue = $QueueStat.$ParName
   # Параметр не определен - инициализация нулевым значением
   if($ParValue -eq $null){ $ParValue = 0 }
   # Вывод имени и значения параметра в формате zabbix_sender
   $OutStr += '- rabbitmq.' + $ParName + '[' + $Queue + '] ' + $ParValue + "`n"
  }
 }

 # Удаление последнего перевода строки.
 # Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
 #  --config      файл конфигурации агента;
 #  --host        имя узла сети на сервере Zabbix;
 #  --input-file  файл данных('-' - стандартный ввод)
 $OutStr.TrimEnd("`n") | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.имя.сервера" --input-file - 2>&1 | Out-Null

 # Возврат статуса сервиса - 'работает'
 Write-Host 1
}
