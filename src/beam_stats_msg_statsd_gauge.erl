-module(beam_stats_msg_statsd_gauge).

-include("include/beam_stats_msg_graphite.hrl").
-include("include/beam_stats_msg_statsd_gauge.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ of_msg_graphite/1
    , to_bin/1
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
    PathBin = beam_stats_msg_graphite:path_to_bin(Path),
    cons(PathBin, Value).

-spec cons(binary(), non_neg_integer()) ->
    t().
cons(<<Name/binary>>, Value) ->
    ?T
    { name  = Name
    , value = Value
    }.

-spec to_bin(t()) ->
    binary().
to_bin(
    ?T
    { name  = <<Name/binary>>
    , value = Value
    }
) when Value >= 0 ->
    ValueBin = integer_to_binary(Value),
    << Name/binary, ":", ValueBin/binary, "|g\n">>.
