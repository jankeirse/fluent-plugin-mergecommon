Gem::Specification.new do |s|
  s.name        = 'fluent-plugin-mergecommon'
  s.version     = '0.1.0'
  s.licenses    = ['MIT']
  s.summary     = "concat/sum up related events in fluentd"
  s.description = "Fluentd filter plugin for merging successive events (concatenating/summing up fields) if they have a number of fields in common"
  s.authors     = ["Jan Keirse @ TVH Parts Holding NV"]
  s.email       = 'jan.keirse@tvh.com'
  s.files       = ["lib/fluent/plugin/filter_merge_common.rb"]
  s.homepage    = 'https://github.com/jankeirse/fluent-plugin-mergecommon'
  s.metadata    = { "source_code_uri" => "https://github.com/jankeirse/fluent-plugin-mergecommon.git" }
end