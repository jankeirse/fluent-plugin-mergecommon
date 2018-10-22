# fluentd-plugin-mergecommon
Fluentd filter plugin for merging successive events (concatenating fields) if they have a number of fields in common

A config like this:
<pre>
&lt;source&gt;
  &#64;type tail
  format /^\[(?&lt;time&gt;\d{2}/\d{2}/\d{2}&#64;\d{2}:\d{2}:\d{2}\.\d{3}\+\d{4})\] P-(?&lt;pid&gt;\d+) T-(?&lt;thread&gt;\d+) (?&lt;loglevel&gt;\d+) (?&lt;executionenvironment&gt;[^\s\\]+) (?&lt;logentrytype&gt;[^\s\\]+)\s+(?&lt;message&gt;.*)$/
  time_format %d/%m/%y&#64;%H:%M:%S.%N+%z
  path shortlog.log
  read_from_head true
  tag agent-log
&lt;/source&gt;
&lt;filter agent-log&gt;
    &#64;type merge_common
    key message
    multiline_matching_fields timestamp,pid,thread,loglevel,executionenvironment,logentrytype
    multiline_concat_fields ["message"]
    flush_interval 1
    timeout_label alltimeout
&lt;/filter&gt;
&lt;match **&gt;
  &#64;type stdout
  output_type hash
&lt;/match&gt;
</pre>

Will handle a logfile that looks like this: 
<pre>
[18/10/19&#64;16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19&#64;16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### Begin Web Handler Request: GET /Entities/pick-stations
[18/10/19&#64;16:04:08.013+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19&#64;16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
[18/10/19&#64;16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### End Web Handler Request: GET /Entities/pick-stations
[18/10/19&#64;16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ### Request runtime: 29 msecs, Response Content Length: 14623 bytes
[18/10/19&#64;16:04:08.042+0200] P-012528 T-1711302400 1 AS-8 SmartWebHa     ##############################################################################################################################
</pre>
And output events like this:

<pre>
2019-10-18 16:04:08.013000000 +0200 agent-log: {"pid"=&gt;"012528", "thread"=&gt;"1711302400", "loglevel"=&gt;"1", "executionenvironment"=&gt;"AS-8", "logentrytype"=&gt;"SmartWebHa", "message"=&gt;"################################################################################################################################# Begin Web Handler Request: GET /Entities/pick-stations##############################################################################################################################"}

2019-10-18 16:04:08.042000000 +0200 agent-log: {"pid"=&gt;"012528", "thread"=&gt;"1711302400", "loglevel"=&gt;"1", "executionenvironment"=&gt;"AS-8", "logentrytype"=&gt;"SmartWebHa", "message"=&gt;"################################################################################################################################# End Web Handler Request: GET /Entities/pick-stations### Request runtime: 29 msecs, Response Content Length: 14623 bytes##############################################################################################################################"}
</pre>
