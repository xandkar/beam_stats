-record(beam_stats_process_ancestry,
    { raw_initial_call  ::               mfa()
    , otp_initial_call  :: hope_option:t(mfa())
    , otp_ancestors     ::               [{name, atom()} | {call, mfa()}]
    }).
