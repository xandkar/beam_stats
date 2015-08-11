-module(beam_stats).

-include("include/beam_stats.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ collect/0
    ]).

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec collect() ->
    t().
collect() ->
    ?T
    { timestamp = os:timestamp()
    , node_id   = erlang:node()
    , memory    = erlang:memory()
    }.
