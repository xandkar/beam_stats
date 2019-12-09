-module(beam_stats_process).

-include("include/beam_stats_process_ancestry.hrl").
-include("include/beam_stats_process.hrl").

-export_type(
    [ t/0
    , status/0
    , ancestry/0
    , best_known_origin/0
    ]).

-export(
    [ of_pid/2
    , get_best_known_origin/1
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

-type ancestry() ::
    #beam_stats_process_ancestry{}.

-type best_known_origin() ::
      {registered_name , atom()}
    | {ancestry        , ancestry()}
    .

-define(T, #?MODULE).

-type t() ::
    ?T{}.

%% ============================================================================
%% Public API
%% ============================================================================

-spec of_pid(pid(), beam_stats_delta:t()) ->
      none        % when process is dead
    | {some, t()} % when process is alive
    .
of_pid(Pid, DeltasServer) ->
    try
        Dict = pid_info_exn(Pid, dictionary),
        Ancestry =
            #beam_stats_process_ancestry
            { raw_initial_call  = pid_info_exn(Pid, initial_call)
            , otp_initial_call  = hope_kv_list:get(Dict, '$initial_call')
            , otp_ancestors     = hope_kv_list:get(Dict, '$ancestors')
            },
        T =
            ?T
            { pid               = Pid
            , registered_name   = pid_info_opt(Pid, registered_name)
            , ancestry          = Ancestry
            , status            = pid_info_exn(Pid, status)
            , memory            = pid_info_exn(Pid, memory)
            , total_heap_size   = pid_info_exn(Pid, total_heap_size)
            , stack_size        = pid_info_exn(Pid, stack_size)
            , message_queue_len = pid_info_exn(Pid, message_queue_len)
            , reductions        = pid_info_reductions(Pid, DeltasServer)
            },
        {some, T}
    catch throw:{process_dead, _} ->
        none
    end.

-spec print(t()) ->
    ok.
print(
    ?T
    { pid               = Pid
    , registered_name   = RegisteredNameOpt
    , ancestry          = #beam_stats_process_ancestry
        { raw_initial_call = InitialCallRaw
        , otp_initial_call = InitialCallOTPOpt
        , otp_ancestors    = AncestorsOpt
        }
    , status            = Status
    , memory            = Memory
    , total_heap_size   = TotalHeapSize
    , stack_size        = StackSize
    , message_queue_len = MsgQueueLen
    , reductions        = Reductions
    }=T
) ->
    BestKnownOrigin = get_best_known_origin(T),
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
        "Reductions        : ~p~n"
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
        , Reductions
        ]
    ).

%% ============================================================================
%% Private helpers
%% ============================================================================

-spec pid_info_reductions(pid(), beam_stats_delta:t()) ->
    non_neg_integer().
pid_info_reductions(Pid, DeltasServer) ->
    case beam_stats_delta:of_process_info_reductions(DeltasServer, Pid)
    of  {some, Reductions} ->
            Reductions
    ;   none ->
            throw({process_dead, Pid})
    end.

pid_info_exn(Pid, Key) ->
    {some, Value} = pid_info_opt(Pid, Key),
    Value.

pid_info_opt(Pid, Key) ->
    case {Key, beam_stats_source:erlang_process_info(Pid, Key)}
    of  {registered_name, []}           -> none
    ;   {_              , {Key, Value}} -> {some, Value}
    ;   {_              , undefined}    -> throw({process_dead, Pid})
    end.

%% ============================================================================
%% Process code origin approximation or naming the anonymous processes.
%%
%% At runtime, given a PID, how precisely can we identify the origin of the
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

-spec get_best_known_origin(t()) ->
    best_known_origin().
get_best_known_origin(?T{registered_name={some, RegisteredName}}) ->
    {registered_name, RegisteredName};
get_best_known_origin(?T{registered_name=none, ancestry=Ancestry}) ->
    {ancestry, Ancestry}.
