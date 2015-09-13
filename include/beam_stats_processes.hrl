-record(beam_stats_processes,
    { individual_stats         = [] :: [beam_stats_process:t()]
    , count_all                = 0  :: non_neg_integer()
    , count_exiting            = 0  :: non_neg_integer()
    , count_garbage_collecting = 0  :: non_neg_integer()
    , count_registered         = 0  :: non_neg_integer()
    , count_runnable           = 0  :: non_neg_integer()
    , count_running            = 0  :: non_neg_integer()
    , count_suspended          = 0  :: non_neg_integer()
    , count_waiting            = 0  :: non_neg_integer()
    }).
