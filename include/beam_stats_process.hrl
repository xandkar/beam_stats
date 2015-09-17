-record(beam_stats_process,
    { pid               ::               pid()
    , registered_name   :: hope_option:t(atom())
    , ancestry          ::               beam_stats_process:ancestry()
    , status            ::               beam_stats_process:status()
    , memory            ::               non_neg_integer()
    , total_heap_size   ::               non_neg_integer()
    , stack_size        ::               non_neg_integer()
    , message_queue_len ::               non_neg_integer()
    }).
