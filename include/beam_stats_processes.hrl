-record(beam_stats_processes,
    { individual_stats         :: [beam_stats_process:t()]
    , count_all                :: non_neg_integer()
    , count_exiting            :: non_neg_integer()
    , count_garbage_collecting :: non_neg_integer()
    , count_registered         :: non_neg_integer()
    , count_runnable           :: non_neg_integer()
    , count_running            :: non_neg_integer()
    , count_suspended          :: non_neg_integer()
    , count_waiting            :: non_neg_integer()
    }).
