-module(beam_stats_processes).

-include("include/beam_stats_process.hrl").
-include("include/beam_stats_processes.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ collect/1
    , collect_and_print/1
    , print/1
    ]).

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec collect(beam_stats_delta:t()) ->
    t().
collect(DeltasServer) ->
    Pids = beam_stats_source:erlang_processes(),
    PsOpts = [beam_stats_process:of_pid(P, DeltasServer) || P <- Pids],
    Ps = [P || {some, P} <- PsOpts],
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
        = length(beam_stats_source:erlang_registered())
    , count_runnable
        = length([P || P <- Ps, P#beam_stats_process.status =:= runnable])
    , count_running
        = length([P || P <- Ps, P#beam_stats_process.status =:= running])
    , count_suspended
        = length([P || P <- Ps, P#beam_stats_process.status =:= suspended])
    , count_waiting
        = length([P || P <- Ps, P#beam_stats_process.status =:= waiting])
    }.

-spec collect_and_print(beam_stats_delta:t()) ->
    ok.
collect_and_print(DeltasServer) ->
    print(collect(DeltasServer)).

-spec print(t()) ->
    ok.
print(
    ?T
    { individual_stats         = PerProcessStats
    , count_all                = CountAll
    , count_exiting            = CountExiting
    , count_garbage_collecting = CountGarbageCollecting
    , count_registered         = CountRegistered
    , count_runnable           = CountRunnable
    , count_running            = CountRunning
    , count_suspended          = CountSuspended
    , count_waiting            = CountWaiting
    }
) ->
    PerProcessStatsSorted = lists:sort(
        fun (#beam_stats_process{memory=A}, #beam_stats_process{memory=B}) ->
            % From lowest to highest, so that the largest appears the end of
            % the output and be easier to see (without scrolling back):
            A < B
        end,
        PerProcessStats
    ),
    lists:foreach(fun beam_stats_process:print/1, PerProcessStatsSorted),
    io:format("==================================================~n"),
    io:format(
        "CountAll               : ~b~n"
        "CountExiting           : ~b~n"
        "CountGarbageCollecting : ~b~n"
        "CountRegistered        : ~b~n"
        "CountRunnable          : ~b~n"
        "CountRunning           : ~b~n"
        "CountSuspended         : ~b~n"
        "CountWaiting           : ~b~n"
        "~n",
        [ CountAll
        , CountExiting
        , CountGarbageCollecting
        , CountRegistered
        , CountRunnable
        , CountRunning
        , CountSuspended
        , CountWaiting
        ]
    ).
