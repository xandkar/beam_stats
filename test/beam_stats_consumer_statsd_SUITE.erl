-module(beam_stats_consumer_statsd_SUITE).

-include_lib("beam_stats/include/beam_stats.hrl").
-include_lib("beam_stats/include/beam_stats_ets_table.hrl").

-export(
    [ all/0
    , groups/0
    ]).

%% Test cases
-export(
    [ t_send/1
    ]).

-define(GROUP, beam_stats_consumer_statsd).

%% ============================================================================
%% Common Test callbacks
%% ============================================================================

all() ->
    [{group, ?GROUP}].

groups() ->
    Tests =
        [ t_send
        ],
    Properties = [],
    [{?GROUP, Properties, Tests}].

%% =============================================================================
%%  Test cases
%% =============================================================================

t_send(_Cfg) ->
    ETSTableStatsFoo =
        #beam_stats_ets_table
        { id     = foo
        , name   = foo
        , size   = 5
        , memory = 25
        },
    ETSTableStatsBar =
        #beam_stats_ets_table
        { id     = 37
        , name   = bar
        , size   = 8
        , memory = 38
        },
    % TODO: Indent #beam_stats as #beam_stats_ets_table
    BEAMStats = #beam_stats
    { timestamp = {1, 2, 3}
    , node_id   = 'node_foo@host_bar'
    , memory    = [{mem_type_foo, 1}]
    , io_bytes_in  = 3
    , io_bytes_out = 7
    , context_switches = 5
    , reductions       = 9
    , run_queue        = 17
    , ets              = [ETSTableStatsFoo, ETSTableStatsBar]
    },
    ServerPort = 8125,
    {ok, ServerSocket} = gen_udp:open(ServerPort, [binary, {active, false}]),
    BEAMStatsQ = queue:in(BEAMStats, queue:new()),
    Options = [{dst_port, ServerPort}],
    {_, State1} = beam_stats_consumer_statsd:init(Options),
    State2 = beam_stats_consumer_statsd:consume(BEAMStatsQ, State1),
    {} = beam_stats_consumer_statsd:terminate(State2),
    ResultOfReceive = gen_udp:recv(ServerSocket, 0),
    ok = gen_udp:close(ServerSocket),
    {ok, {_, _, Data}} = ResultOfReceive,
    ct:log("Packet: ~n~s~n", [Data]),
    << "beam_stats.node_foo_host_bar.io.bytes_in:3|g\n"
     , "beam_stats.node_foo_host_bar.io.bytes_out:7|g\n"
     , "beam_stats.node_foo_host_bar.context_switches:5|g\n"
     , "beam_stats.node_foo_host_bar.reductions:9|g\n"
     , "beam_stats.node_foo_host_bar.run_queue:17|g\n"
     , "beam_stats.node_foo_host_bar.memory.mem_type_foo:1|g\n"
     , "beam_stats.node_foo_host_bar.ets_table.size.foo.foo:5|g\n"
     , "beam_stats.node_foo_host_bar.ets_table.memory.foo.foo:25|g\n"
     , "beam_stats.node_foo_host_bar.ets_table.size.bar.37:8|g\n"
     , "beam_stats.node_foo_host_bar.ets_table.memory.bar.37:38|g\n"
    >> = Data.
