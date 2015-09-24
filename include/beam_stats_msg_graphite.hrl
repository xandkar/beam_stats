-record(beam_stats_msg_graphite,
    { path      :: [binary()]
    , value     :: integer()
    , timestamp :: erlang:timestamp()
    }).
