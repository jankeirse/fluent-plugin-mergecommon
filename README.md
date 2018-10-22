# fluentd-plugin-mergecommon
Fluentd filter plugin for merging successive events (concatenating fields) if they have a number of fields in common

A config like this:
<source>
  @type tail
  format /^\[(?<time>\d{2}/\d{2}/\d{2}@\d{2}:\d{2}:\d{2}\.\d{3}\+\d{4})\] P-(?<pid>\d+) T-(?<thread>\d+) (?<loglevel>\d+) (?<executionenvironment>[^\s\\]+) (?<logentrytype>[^\s\\]+)\s+(?<message>.*)$/
  time_format %d/%m/%y@%H:%M:%S.%N+%z
  path shortlog.log
  read_from_head true
  tag agent-log
</source>
<filter agent-log>
    @type merge_common
    key message
    multiline_matching_fields timestamp,pid,thread,loglevel,executionenvironment,logentrytype
    multiline_concat_fields ["message"]
    flush_interval 1
    timeout_label alltimeout
</filter>
<label alltimeout>
    <match **>
      @type stdout
      output_type hash
    </match>
</label>
<match **>
  @type stdout
  output_type hash
</match>


Will handle a logfile that looks like this: 

[18/10/19@16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19@16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### Begin Web Handler Request: GET /Entities/pick-stations
[18/10/19@16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19@16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19@16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### End Web Handler Request: GET /Entities/pick-stations
[18/10/19@16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### Request runtime: 29 msecs, Response Content Length: 14623 bytes
[18/10/19@16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################

And output events like this:

2019-10-18 16:04:08.013000000 +0200 agent-log: {"pid"=>"012528", "thread"=>"1711302400", "loglevel"=>"1", "executionenvironment"=>"AS-8", "logentrytype"=>"SmartWebHa", "message"=>"################################################################################################################################# Begin Web Handler Request: GET /Entities/pick-stations##############################################################################################################################"}

2019-10-18 16:04:08.042000000 +0200 agent-log: {"pid"=>"012528", "thread"=>"1711302400", "loglevel"=>"1", "executionenvironment"=>"AS-8", "logentrytype"=>"SmartWebHa", "message"=>"################################################################################################################################# End Web Handler Request: GET /Entities/pick-stations### Request runtime: 29 msecs, Response Content Length: 14623 bytes##############################################################################################################################"}