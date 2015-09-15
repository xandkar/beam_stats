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
    , memory    = [{mem_type_foo, 1}, {mem_type_bar, 2}, {mem_type_baz, 3}]
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
    ResultOfReceive1 = gen_udp:recv(ServerSocket, 0),
    {ok, {_, _, PacketReceived1}} = ResultOfReceive1,
    ResultOfReceive2 = gen_udp:recv(ServerSocket, 0),
    {ok, {_, _, PacketReceived2}} = ResultOfReceive2,
    ok = gen_udp:close(ServerSocket),
    ct:log("PacketReceived1: ~n~s~n", [PacketReceived1]),
    ct:log("PacketReceived2: ~n~s~n", [PacketReceived2]),
    PacketsCombined = <<PacketReceived1/binary, PacketReceived2/binary>>,
    ct:log("PacketsCombined: ~n~s~n", [PacketsCombined]),
    MsgsExpected =
        [ <<"beam_stats.node_foo_host_bar.io.bytes_in:3|g">>
        , <<"beam_stats.node_foo_host_bar.io.bytes_out:7|g">>
        , <<"beam_stats.node_foo_host_bar.context_switches:5|g">>
        , <<"beam_stats.node_foo_host_bar.reductions:9|g">>
        , <<"beam_stats.node_foo_host_bar.run_queue:17|g">>
        , <<"beam_stats.node_foo_host_bar.memory.mem_type_foo:1|g">>
        , <<"beam_stats.node_foo_host_bar.memory.mem_type_bar:2|g">>
        , <<"beam_stats.node_foo_host_bar.memory.mem_type_baz:3|g">>
        , <<"beam_stats.node_foo_host_bar.ets_table.size.foo.foo:5|g">>
        , <<"beam_stats.node_foo_host_bar.ets_table.memory.foo.foo:25|g">>
        , <<"beam_stats.node_foo_host_bar.ets_table.size.bar.37:8|g">>
        , <<"beam_stats.node_foo_host_bar.ets_table.memory.bar.37:38|g">>
        ],
    MsgsReceived = binary:split(PacketsCombined, <<"\n">>, [global, trim]),
    RemoveExpectedFromReceived =
        fun (Expected, Received) ->
            ct:log(
                "Looking for expected msg ~p in remaining received ~p~n",
                [Expected, Received]
            ),
            true = lists:member(Expected, Received),
            Received -- [Expected]
        end,
    [] = lists:foldl(RemoveExpectedFromReceived, MsgsReceived, MsgsExpected).
