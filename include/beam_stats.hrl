-record(beam_stats,
    { timestamp        :: erlang:timestamp()
    , node_id          :: atom()
    , memory           :: [{atom(), non_neg_integer()}]
    , io_bytes_in      :: non_neg_integer()
    , io_bytes_out     :: non_neg_integer()
    , context_switches :: non_neg_integer()
    , reductions       :: non_neg_integer()
    , run_queue        :: non_neg_integer()
    , ets              :: beam_stats_ets:t()
    , processes        :: beam_stats_processes:t()

    %, statistics   :: [{atom()       , term()}]
    %, system       :: [{atom()       , term()}]
    %, port         :: [{atom()       , term()}]
    %, dets         :: [{atom()       , term()}]
    }).
