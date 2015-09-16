-module(beam_stats_process).

-include("include/beam_stats_process.hrl").

-export_type(
    [ t/0
    , status/0
    , ancestor/0
    , best_known_origin/0
    ]).

-export(
    [ of_pid/1
    , best_known_origin/1
    , print/1
    ]).

-type status() ::
      exiting
    | garbage_collecting
    | runnable
    | running
    | suspended
    | waiting
    .

-type ancestor() ::
      {otp_ancestors    , [pid() | atom()]}
    | {otp_initial_call , mfa()}
    | {raw_initial_call , mfa()}
    .

-type best_known_origin() ::
      {registered_name , atom()}
    | {ancestry        , [ancestor()]}
    .

-define(T, #?MODULE).

-type t() ::
    ?T{}.

%% ============================================================================
%% Public API
%% ============================================================================

-spec of_pid(pid()) ->
    t().
of_pid(Pid) ->
    Dict = pid_info_exn(Pid, dictionary),
    ?T
    { pid               = Pid
    , registered_name   = pid_info_opt(Pid, registered_name)
    , raw_initial_call  = pid_info_exn(Pid, initial_call)
    , otp_initial_call  = hope_kv_list:get(Dict, '$initial_call')
    , otp_ancestors     = hope_kv_list:get(Dict, '$ancestors')
    , status            = pid_info_exn(Pid, status)
    , memory            = pid_info_exn(Pid, memory)
    , total_heap_size   = pid_info_exn(Pid, total_heap_size)
    , stack_size        = pid_info_exn(Pid, stack_size)
    , message_queue_len = pid_info_exn(Pid, message_queue_len)
    }.

-spec print(t()) ->
    ok.
print(
    ?T
    { pid               = Pid
    , registered_name   = RegisteredNameOpt
    , raw_initial_call  = InitialCallRaw
    , otp_initial_call  = InitialCallOTPOpt
    , otp_ancestors     = AncestorsOpt
    , status            = Status
    , memory            = Memory
    , total_heap_size   = TotalHeapSize
    , stack_size        = StackSize
    , message_queue_len = MsgQueueLen
    }=T
) ->
    BestKnownOrigin = best_known_origin(T),
    io:format("--------------------------------------------------~n"),
    io:format(
        "Pid               : ~p~n"
        "BestKnownOrigin   : ~p~n"
        "RegisteredNameOpt : ~p~n"
        "InitialCallRaw    : ~p~n"
        "InitialCallOTPOpt : ~p~n"
        "AncestorsOpt      : ~p~n"
        "Status            : ~p~n"
        "Memory            : ~p~n"
        "TotalHeapSize     : ~p~n"
        "StackSize         : ~p~n"
        "MsgQueueLen       : ~p~n"
        "~n",
        [ Pid
        , BestKnownOrigin
        , RegisteredNameOpt
        , InitialCallRaw
        , InitialCallOTPOpt
        , AncestorsOpt
        , Status
        , Memory
        , TotalHeapSize
        , StackSize
        , MsgQueueLen
        ]
    ).

%% ============================================================================
%% Private helpers
%% ============================================================================

pid_info_exn(Pid, Key) ->
    {some, Value} = pid_info_opt(Pid, Key),
    Value.

pid_info_opt(Pid, Key) ->
    case {Key, erlang:process_info(Pid, Key)}
    of  {registered_name, []}           -> none
    ;   {_              , {Key, Value}} -> {some, Value}
    end.

%% ============================================================================
%% Process code origin approximation or naming the anonymous processes.
%%
%% At runtime, given a PID, how precicely can we identify the origin of the
%% code it is running?
%%
%% We have these data points:
%%
%% - Sometimes   | registered name (if so, we're done)
%% - Sometimes   | ancestor PIDs or registered names
%% - Always      | initial_call (can be too generic, such as erlang:apply)
%% - Always      | current_function (can be too far down the stack)
%% - Always      | current_location (can be too far down the stack)
%% - Potentially | application tree, but maybe expensive to compute, need to check
%% ============================================================================

-define(TAG(Tag), fun (X) -> {Tag, X} end).

-spec best_known_origin(t()) ->
    best_known_origin().
best_known_origin(?T{registered_name={some, RegisteredName}}) ->
    {registered_name, RegisteredName};
best_known_origin(
    ?T
    { pid               = _Pid
    , registered_name   = none
    , raw_initial_call  = InitCallRaw
    , otp_initial_call  = InitCallOTPOpt1
    , otp_ancestors     = AncestorsOpt1
    , status            = _Status
    , memory            = _Memory
    , total_heap_size   = _TotalHeapSize
    , stack_size        = _StackSize
    , message_queue_len = _MsgQueueLen
    }
) ->
    ToSingleton       = fun (X) -> [X] end,
    InitCallOTPOpt2   = hope_option:map(InitCallOTPOpt1, ?TAG(otp_initial_call)),
    AncestorsOpt2     = hope_option:map(AncestorsOpt1  , ?TAG(otp_ancestors)),
    InitCallOTPOpt3   = hope_option:map(InitCallOTPOpt2, ToSingleton),
    AncestorsOpt3     = hope_option:map(AncestorsOpt2  , ToSingleton),
    MaybeInitCallOTP  = hope_option:get(InitCallOTPOpt3, []),
    MaybeAncestors    = hope_option:get(AncestorsOpt3  , []),
    Ancestry =
        [{raw_initial_call, InitCallRaw}] ++
        MaybeInitCallOTP ++
        MaybeAncestors,
    {ancestry, Ancestry}.
