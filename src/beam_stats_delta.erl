-module(beam_stats_delta).

-export_type(
    [ t/0
    ]).

-export(
    [ start/0
    , stop/1
    , of_context_switches/1
    , of_io/1
    , of_reductions/1
    ]).

-record(?MODULE,
    { erlang_statistics :: ets:tid()
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
    { erlang_statistics = ets:new(beam_stats_delta_erlang_statistics, Options)
    }.

-spec stop(t()) ->
    {}.
stop(?T
    { erlang_statistics = TidErlangStatistics
    }
) ->
    true = ets:delete(TidErlangStatistics),
    {}.

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

-spec delta(ets:tid(), atom(), non_neg_integer()) ->
    non_neg_integer().
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
