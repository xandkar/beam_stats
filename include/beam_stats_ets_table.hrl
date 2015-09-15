-record(beam_stats_ets_table,
    { id     :: beam_stats_ets_table:id()
    , name   :: atom()
    , size   :: non_neg_integer()
    , memory :: non_neg_integer()
    }).
