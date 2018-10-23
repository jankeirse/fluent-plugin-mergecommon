# fluentd-plugin-mergecommon
Fluentd filter plugin for merging successive events (concatenating fields) if they have a number of fields in common
## Requirements

| fluent-plugin-concat | fluentd    | ruby   |
|----------------------|------------|--------|
| >= 2.0.0             | >= v0.14.0 | >= 2.1 |
| < 2.0.0              | >= v0.12.0 | >= 1.9 |

## Configuration

**multiline_matching_fields** (string array) (required)

The fields that have to match before merging, you can use time or timestamp if the time of the event has to match. 
If the event contains a field time or timestamp the event field will be compared instead, so use what is not in the event. 
If your events contain both a time and timestamp field and you still want to compare the event time itself, you'll need to create a pull request. 

**multiline_concat_fields** (string array)

The fields that should be concattenated with same field of each matching event.

**multiline_concat_seperator** (string) (default: \n) 

The separator between merge_concat_fields

**multiline_sum_fields** (string array)

The fields that should be summed with same field of each matching event

**multiline_count_field** (string)

The field in which to store the number of events that have been merged, ommitted from output if nil which is the default.

**stream_identity_key** (string)

The key to determine which stream an event belongs to. If you use this the contents of the field in the events will be used to identify seperate streams and each seperate stream has it's own seperate matching event flow. Default: nil.

**flush_interval** (time) 

The interval between data flushes, 0 means disable timeout. After a timeout the event is flushed, if disabled it is only flushed after the next event that does not match the fields that have to match, which might cause log entries to be delayed significantly in logs that don't get a lot of new contents. 
Defaults to 1.

**use_first_timestamp** (bool)

Use timestamp of first record when buffer is flushed, otherwise it's the time the last event is flushed. Defaults to true.

**tag_postfix** (string)
This is added to the tag of the original event when outputing the resulting event stream. This is necessary to avoid deadlocks in fluentd logic. Defaults to ".multiline" .
    
## Original purpose

This plugin was originally written to handle OpenEdge ABL log files. It can be adapted to support at least Pacific and classic Appserver Agent Logs and Client Logs. 
	
## sample usage	

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
2019-10-18 16:04:08.013000000 +0200 agent-log.multiline: {"pid"=&gt;"012528", "thread"=&gt;"1711302400", "loglevel"=&gt;"1", "executionenvironment"=&gt;"AS-8", "logentrytype"=&gt;"SmartWebHa", "message"=&gt;"################################################################################################################################# Begin Web Handler Request: GET /Entities/pick-stations##############################################################################################################################"}

2019-10-18 16:04:08.042000000 +0200 agent-log.multiline: {"pid"=&gt;"012528", "thread"=&gt;"1711302400", "loglevel"=&gt;"1", "executionenvironment"=&gt;"AS-8", "logentrytype"=&gt;"SmartWebHa", "message"=&gt;"################################################################################################################################# End Web Handler Request: GET /Entities/pick-stations### Request runtime: 29 msecs, Response Content Length: 14623 bytes##############################################################################################################################"}
</pre>
