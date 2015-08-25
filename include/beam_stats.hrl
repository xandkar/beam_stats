-record(beam_stats,
    { timestamp    :: erlang:timestamp()
    , node_id      :: atom()
    , memory       :: [{atom(), non_neg_integer()}]
    , io_bytes_in  :: non_neg_integer()
    , io_bytes_out :: non_neg_integer()
    , context_switches :: non_neg_integer()
    , reductions       :: non_neg_integer()
    %, statistics   :: [{atom()       , term()}]
    %, system       :: [{atom()       , term()}]
    %, process      :: [{atom()       , term()}]
    %, port         :: [{atom()       , term()}]
    %, ets          :: [{atom()       , term()}]
    %, dets         :: [{atom()       , term()}]
    }).
