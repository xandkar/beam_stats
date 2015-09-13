-record(beam_stats_process,
    { pid               ::               pid()
    , registered_name   :: hope_option:t(atom())
    , raw_initial_call  ::               mfa()
    , otp_initial_call  :: hope_option:t(mfa())
    , otp_ancestors     ::               [{name, atom()} | {call, mfa()}]
    , status            ::               beam_stats_process:status()
    , memory            ::               non_neg_integer()
    , total_heap_size   ::               non_neg_integer()
    , stack_size        ::               non_neg_integer()
    , message_queue_len ::               non_neg_integer()
    }).
