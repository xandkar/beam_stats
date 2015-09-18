-module(beam_stats_processes).

-include("include/beam_stats_process.hrl").
-include("include/beam_stats_processes.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ collect/0
    , collect_and_print/0
    , print/1
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

collect_and_print() ->
    print(collect()).

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
            % From lowest to highest:
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
