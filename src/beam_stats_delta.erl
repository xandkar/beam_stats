-module(beam_stats_delta).

-export_type(
    [ t/0
    ]).

-export(
    [ start/0
    , stop/1
    , gc/1
    , of_context_switches/1
    , of_io/1
    , of_reductions/1
    , of_process_info_reductions/2
    ]).

-record(?MODULE,
    { erlang_statistics :: ets:tid()
    , erlang_process_info_reductions :: ets:tid()
    }).

-define(T, #?MODULE).

-opaque t()  ::
    ?T{}.

-spec start() ->
    t().
start() ->
    Options =
        [ set
        , public
        ],
    ?T
    { erlang_statistics =
        ets:new(beam_stats_delta_erlang_statistics, Options)
    , erlang_process_info_reductions =
        ets:new(beam_stats_delta_erlang_process_info_reductions, Options)
    }.

-spec stop(t()) ->
    {}.
stop(?T
    { erlang_statistics              = TidErlangStatistics
    , erlang_process_info_reductions = TidErlangProcessInfoReductions
    }
) ->
    true = ets:delete(TidErlangStatistics),
    true = ets:delete(TidErlangProcessInfoReductions),
    {}.

-spec gc(t()) ->
    {}.
gc(?T{erlang_process_info_reductions=Table}=T) ->
    case ets:first(Table)
    of  '$end_of_table' ->
            {}
    ;   FirstPid when is_pid(FirstPid) ->
            gc(T, FirstPid)
    end.

-spec gc(t(), pid()) ->
    {}.
gc(?T{erlang_process_info_reductions=Table}=T, Pid) ->
    Next = ets:next(Table, Pid),
    case beam_stats_source:erlang_is_process_alive(Pid)
    of  true  -> true
    ;   false -> ets:delete(Table, Pid)
    end,
    case Next
    of  '$end_of_table' ->
            {}
    ;   NextPid when is_pid(NextPid) ->
            gc(T, NextPid)
    end.

-spec of_context_switches(t()) ->
    non_neg_integer().
of_context_switches(?T{erlang_statistics=Table}) ->
    Key = context_switches,
    {Current, 0} = beam_stats_source:erlang_statistics(Key),
    delta(Table, Key, Current).

-spec of_io(t()) ->
    { {io_bytes_in  , non_neg_integer()}
    , {io_bytes_out , non_neg_integer()}
    }.
of_io(?T{erlang_statistics=Table}) ->
    Key = io,
    { {input  , CurrentIn}
    , {output , CurrentOut}
    } = beam_stats_source:erlang_statistics(Key),
    DeltaIn  = delta(Table, io_bytes_in , CurrentIn),
    DeltaOut = delta(Table, io_bytes_out, CurrentOut),
    { {io_bytes_in  , DeltaIn}
    , {io_bytes_out , DeltaOut}
    }.

% We can get between-calls-delta directly from erlang:statistics(reductions),
% but then if some other process also calls it - we'll get incorrect data on
% the next call.
% Managing deltas ourselves here, will at least reduce the possible callers to
% only those with knowledge of our table ID.
-spec of_reductions(t()) ->
    non_neg_integer().
of_reductions(?T{erlang_statistics=Table}) ->
    Key = reductions,
    {Current, _} = beam_stats_source:erlang_statistics(Key),
    delta(Table, Key, Current).

-spec of_process_info_reductions(t(), pid()) ->
    hope_option:t(non_neg_integer()).
of_process_info_reductions(?T{erlang_process_info_reductions=Table}, Pid) ->
    case beam_stats_source:erlang_process_info(Pid, reductions)
    of  undefined ->
            none
    ;   {reductions, Current} ->
            Delta = delta(Table, Pid, Current),
            {some, Delta}
    end.

-spec delta(ets:tid(), Key, non_neg_integer()) ->
    non_neg_integer()
    when Key :: atom() | pid().
delta(Table, Key, CurrentTotal) ->
    PreviousTotalOpt = find(Table, Key),
    PreviousTotal = hope_option:get(PreviousTotalOpt, 0),
    save(Table, Key, CurrentTotal),
    CurrentTotal - PreviousTotal.

-spec find(ets:tid(), term()) ->
    hope_option:t(term()).
find(Table, K) ->
    case ets:lookup(Table, K)
    of  []       -> none
    ;   [{K, V}] -> {some, V}
    end.

-spec save(ets:tid(), term(), term()) ->
    {}.
save(Table, K, V) ->
    true = ets:insert(Table, {K, V}),
    {}.
