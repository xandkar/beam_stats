-module(beam_stats_processes).

-include("include/beam_stats_process.hrl").
-include("include/beam_stats_processes.hrl").

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
    Ps = [beam_stats_process:of_pid(P) || P <- erlang:processes()],
    ?T
    { individual_stats
        = Ps
    , count_all
        = length(Ps)
    , count_exiting
        = length([P || P <- Ps, P#beam_stats_process.status =:= exiting])
    , count_garbage_collecting
        = length([P || P <- Ps, P#beam_stats_process.status =:= garbage_collecting])
    , count_registered
        = length(registered())
    , count_runnable
        = length([P || P <- Ps, P#beam_stats_process.status =:= runnable])
    , count_running
        = length([P || P <- Ps, P#beam_stats_process.status =:= running])
    , count_suspended
        = length([P || P <- Ps, P#beam_stats_process.status =:= suspended])
    , count_waiting
        = length([P || P <- Ps, P#beam_stats_process.status =:= waiting])
    }.
