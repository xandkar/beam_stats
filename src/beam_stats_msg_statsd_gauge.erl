-module(beam_stats_msg_statsd_gauge).

-include("include/beam_stats_msg_graphite.hrl").
-include("include/beam_stats_msg_statsd_gauge.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ of_msg_graphite/1
    , to_iolist/1
    ]).

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec of_msg_graphite(beam_stats_msg_graphite:t()) ->
    t().
of_msg_graphite(
    #beam_stats_msg_graphite
    { path      = Path
    , value     = Value
    , timestamp = _Timestamp
    }
) ->
    PathIOList = beam_stats_msg_graphite:path_to_iolist(Path),
    cons(PathIOList, Value).

-spec cons(iolist(), non_neg_integer()) ->
    t().
cons(Name, Value) ->
    ?T
    { name  = Name
    , value = Value
    }.

-spec to_iolist(t()) ->
    iolist().
to_iolist(
    ?T
    { name  = Name
    , value = Value
    }
) when Value >= 0 ->
    ValueBin = integer_to_binary(Value),
    [Name, <<":">>, ValueBin, <<"|g\n">>].
