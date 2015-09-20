-module(beam_stats_ets).

-export_type(
    [ t/0
    ]).

-export(
    [ collect/0
    ]).

-type t() ::
    [beam_stats_ets_table:t()].

-spec collect() ->
    t().
collect() ->
    TableIDs = beam_stats_source:ets_all(),
    lists:map(fun beam_stats_ets_table:of_id/1, TableIDs).
