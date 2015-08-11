-record(beam_stats,
    { timestamp    :: erlang:timestamp()
    , node_id      :: atom()
    , memory       :: [{atom(), non_neg_integer()}]
    %, statistics   :: [{atom()       , term()}]
    %, system       :: [{atom()       , term()}]
    %, process      :: [{atom()       , term()}]
    %, port         :: [{atom()       , term()}]
    %, ets          :: [{atom()       , term()}]
    %, dets         :: [{atom()       , term()}]
    }).
