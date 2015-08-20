beam_stats
==========

Periodically collects and pushes VM metrics to arbitrary consumers. Defaults to
StatsD and includes off-by-default implementations for Graphite
(`beam_stats_consumer_graphite`) and CSV file (`beam_stats_consumer_csv`)
consumers).

Essentially like `folsomite`, but better. Better in the following ways:

- More-general: consumers other than graphite can be defined
- More-focused: only concerned with VM metrics, while `folsomite` ships off
  _everything_ from `folsom` (in addition to VM metrics)
- Easier-to-reason-about implementation: well-defined metrics-to-binary
  conversions, as opposed to the nearly-arbitrary term-to-string conversions
  used in `folsomite`
- Spec'd, tested and Dialyzed
