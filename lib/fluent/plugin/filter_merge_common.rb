require "fluent/plugin/filter"

module Fluent::Plugin
  class MergeCommonFilter < Filter
    Fluent::Plugin.register_filter("merge_common", self)

    helpers :timer, :event_emitter

    desc "The key for events that have to be merged"
    config_param :key, :string

    desc "The fields that have to match before merging"
    config_param :multiline_matching_fields, :array, value_type: :string
    desc"The fields that should be concattenated with same field of each event where fields match"
    config_param :multiline_concat_fields, :array, value_type: :string
    desc "The separator between merged events"
    config_param :multiline_concat_separator, :string, default: "\n"
    desc "The fields that should be summed with same field of each event where fields match"
    config_param :multiline_sum_fields, :array, value_type: :string, default: nil
    desc "The field in which to store the number of events that have been merged, ommitted from output if nil"
    config_param :multiline_count_field, :string, default: nil
    desc "The key to determine which stream an event belongs to"
    config_param :stream_identity_key, :string, default: nil
    desc "The interval between data flushes, 0 means disable timeout"
    config_param :flush_interval, :time, default: 1
    desc "The label name to handle timeout"
    config_param :timeout_label, :string, default: nil
    desc "Use timestamp of first record when buffer is flushed"
    config_param :use_first_timestamp, :bool, default: true

    class TimeoutError < StandardError
    end

    def initialize
      super

      @buffer = Hash.new {|h, k| h[k] = [] }
      @timeout_map_mutex = Thread::Mutex.new
      @timeout_map_mutex.synchronize do
        @timeout_map = Hash.new {|h, k| h[k] = Fluent::Engine.now }
      end
      @previous_record = Hash.new
      @current_record = Hash.new
    end

    def configure(conf)
      super

      if @multiline_matching_fields.nil? || @multiline_matching_fields.size < 1
        raise Fluent::ConfigError, "You must provide multiline_matching_fields"
      end
    end

    def start
      super
      @finished = false
      timer_execute(:filter_mergecommon_timer, 1, &method(:on_timer))
    end

    def shutdown
      @finished = true
      flush_remaining_buffer
      super
    end

    def filter_stream(tag, es)
      new_es = Fluent::MultiEventStream.new
      es.each do |time, record|
        if /\Afluent\.(?:trace|debug|info|warn|error|fatal)\z/ =~ tag
          new_es.add(time, record)
          next
        end
        unless record.key?(@key)
          new_es.add(time, record)
          next
        end
        begin
          returned_time, event_to_be_emitted = process_event(tag, time, record)
          if event_to_be_emitted
            time = returned_time if @use_first_timestamp
            new_es.add(time, event_to_be_emitted)
          end
        rescue => e
          router.emit_error_event(tag, time, record, e)
        end
      end
      new_es
    end

    private

    def on_timer
      return if @flush_interval <= 0
      return if @finished
      flush_timeout_buffer
    rescue => e
      log.error "failed to flush timeout buffer", error: e
    end

    def process_event(tag, time, record)

      if @stream_identity_key
        stream_identity = "#{tag}:#{record[@stream_identity_key]}"
      else
        stream_identity = "#{tag}:default"
      end
      @timeout_map_mutex.synchronize do
        @timeout_map[stream_identity] = Fluent::Engine.now
      end

      if merge_with_previous_record?(stream_identity, time, record)
        merge_with_previous_record(stream_identity, time, record)
        return nil
      else
        _time, event_for_stream = get_last_record(stream_identity)
        register_new_record(stream_identity, time, record)
        time = _time
        return [time, event_for_stream]
      end
    end

    def register_new_record(stream_identity, time, record)
      @current_record[stream_identity] = [time, record]
    end

    def get_last_record(stream_identity)
      return @current_record[stream_identity]
    end

    def merge_with_previous_record?(stream_identity, time, record)
      previous_time, previous_record = @previous_record[stream_identity]
      @previous_record[stream_identity] = [time, record]
      if previous_record == nil || ! Fluent::EventTime.eq?( previous_time , time)
        return false
      end

      @multiline_matching_fields.each do |field|
        unless record[field] == previous_record[field]
          return false
        end
      end
      return true
    end

    def merge_with_previous_record(stream_identity, time, record)
      if @current_record[stream_identity] == nil
        _record = record
        if @multiline_count_field
          _record[@multiline_count_field] = 1
        end
        @current_record[stream_identity] = [time, _record]
      else
        previous_time, aggregated_record = @current_record[stream_identity]
        if @multiline_concat_fields
          @multiline_concat_fields.each do |field|
            aggregated_record[field] += "#{@multitline_concat_separator}#{record[field]}"
          end
        end

        if @multiline_sum_fields
          @multiline_sum_fields.each do |field|
            aggregated_record[field] += record[field]
          end
        end

        if @multiline_count_field
          aggregated_record[@multiline_count_field] += 1
        end
        @current_record[stream_identity] = [previous_time, aggregated_record]
      end
    end

    def flush_timeout_buffer
      now = Fluent::Engine.now
      timeout_stream_identities = []
      @timeout_map_mutex.synchronize do
        @timeout_map.each do |stream_identity, previous_timestamp|
          next if @flush_interval > (now - previous_timestamp)
          next unless @current_record[stream_identity]
          timeout_stream_identities << stream_identity
          tag = stream_identity.split(":").first
          message = "Timeout flush: #{stream_identity}"
          time, record = @current_record[stream_identity]
          handle_timeout(tag, @use_first_timestamp ? time : now, record)
          @current_record[stream_identity] = nil
          log.info(message)
        end
        @timeout_map.reject! do |stream_identity, _|
          timeout_stream_identities.include?(stream_identity)
        end
      end
    end

    def flush_remaining_buffer
      @current_record.each do |stream_identity, timeandrecord|
        next if timeandrecord == nil
        time, record = timeandrecord
        tag = stream_identity.split(":").first
        handle_timeout(tag,time, record)
      end
      @current_record.clear
    end

    def handle_timeout(tag, time, record)
      if @timeout_label
        event_router = event_emitter_router(@timeout_label)
        event_router.emit(tag, time, record)
      else
        router.emit_error_event(tag, time, record, TimeoutError.new("abc"))
      end
    end
  end
end