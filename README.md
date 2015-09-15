[![Build Status](https://travis-ci.org/ibnfirnas/beam_stats.svg?branch=master)](https://travis-ci.org/ibnfirnas/beam_stats)

beam_stats
==========

Periodically collects and pushes VM metrics to arbitrary consumer processes,
which, in-turn, can do whatever they want with the given data (such as
serialize and forward to some time series storage). Includes, off by default,
example implementations of consumers for:

- StatsD (`beam_stats_consumer_statsd`)
- Graphite (`beam_stats_consumer_graphite`)
- CSV file (`beam_stats_consumer_csv`)

Essentially like `folsomite`, but different. Different in the following ways:

- More-general: consumers other than graphite can be defined
- More-focused: only concerned with VM metrics, while `folsomite` ships off
  _everything_ from `folsom` (in addition to VM metrics)
- Easier-(for me!)-to-reason-about implementation:
    + Well-defined metrics-to-binary conversions, as opposed to the
      nearly-arbitrary term-to-string conversions used in `folsomite`
    + Spec'd, tested and Dialyzed

### Adding consumers

#### At app config time

```erlang
{env,
  [ {production_interval , 30000}
  , {consumers,
      [ {beam_stats_consumer_statsd,
          [ {consumption_interval , 60000}
          , {dst_host             , "localhost"}
          , {dst_port             , 8125}
          , {src_port             , 8124}
          , {num_msgs_per_packet  , 10}
          ]}
      , {beam_stats_consumer_graphite,
          [ {consumption_interval , 60000}
          , {host                 , "localhost"}
          , {port                 , 2003}
          , {timeout              , 5000}
          ]}
      , {beam_stats_consumer_csv,
          [ {consumption_interval , 60000}
          , {path                 , "beam_stats.csv"}
          ]}
      , {some_custom_consumer_module,
          [ {some_custom_option_a, "abc"}
          , {some_custom_option_b, 123}
          ]}

      ]}
  ]}
```

#### Dynamically

```erlang
beam_stats_consumer:add(consumer_module, ConsumerOptions).
```

### Removing consumers

Not yet implemented.
