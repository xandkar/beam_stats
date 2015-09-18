-module(beam_stats_consumer_statsd_SUITE).

-include_lib("beam_stats/include/beam_stats.hrl").
-include_lib("beam_stats/include/beam_stats_ets_table.hrl").
-include_lib("beam_stats/include/beam_stats_process.hrl").
-include_lib("beam_stats/include/beam_stats_process_ancestry.hrl").
-include_lib("beam_stats/include/beam_stats_processes.hrl").

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

%% ============================================================================
%%  Test cases
%% ============================================================================

t_send(_Cfg) ->
    Pid0 = list_to_pid("<0.0.0>"),
    Pid1 = list_to_pid("<0.1.0>"),
    Pid2 = list_to_pid("<0.2.0>"),
    Pid3 = list_to_pid("<0.3.0>"),
    Process1 =
        #beam_stats_process
        { pid               = Pid1
        , registered_name   = {some, reg_name_foo}
        , ancestry =
              #beam_stats_process_ancestry
              { raw_initial_call  = {foo_mod, foo_fun, 2}
              , otp_initial_call  = none
              , otp_ancestors     = none
              }
        , status            = running
        , memory            = 15
        , total_heap_size   = 25
        , stack_size        = 10
        , message_queue_len = 0
        },
    Process2 =
        #beam_stats_process
        { pid               = Pid2
        , registered_name   = none
        , ancestry =
              #beam_stats_process_ancestry
              { raw_initial_call  = {bar_mod, bar_fun, 1}
              , otp_initial_call  = none
              , otp_ancestors     = none
              }
        , status            = running
        , memory            = 25
        , total_heap_size   = 35
        , stack_size        = 40
        , message_queue_len = 5
        },
    Process3 =
        #beam_stats_process
        { pid               = Pid3
        , registered_name   = none
        , ancestry =
              #beam_stats_process_ancestry
              { raw_initial_call  = {baz_mod, baz_fun, 3}
              , otp_initial_call  = {some, {baz_otp_mod, baz_otp_fun, 2}}
              , otp_ancestors     = {some, [Pid0, Pid1]}
              }
        , status            = running
        , memory            = 25
        , total_heap_size   = 35
        , stack_size        = 40
        , message_queue_len = 1
        },
    Processes =
        #beam_stats_processes
        { individual_stats =
            [ Process1
            , Process2
            , Process3
            ]
        , count_all                = 3
        , count_exiting            = 0
        , count_garbage_collecting = 0
        , count_registered         = 1
        , count_runnable           = 0
        , count_running            = 3
        , count_suspended          = 0
        , count_waiting            = 0
        },
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
    , processes        = Processes
    },
    ServerPort = 8125,
    {ok, ServerSocket} = gen_udp:open(ServerPort, [binary, {active, false}]),
    BEAMStatsQ = queue:in(BEAMStats, queue:new()),
    Options = [{dst_port, ServerPort}],
    {_, State1} = beam_stats_consumer_statsd:init(Options),
    State2 = beam_stats_consumer_statsd:consume(BEAMStatsQ, State1),
    {} = beam_stats_consumer_statsd:terminate(State2),
    ResultOfReceive1 = gen_udp:recv(ServerSocket, 0),
    ResultOfReceive2 = gen_udp:recv(ServerSocket, 0),
    ResultOfReceive3 = gen_udp:recv(ServerSocket, 0),
    ResultOfReceive4 = gen_udp:recv(ServerSocket, 0),
    ok = gen_udp:close(ServerSocket),
    {ok, {_, _, PacketReceived1}} = ResultOfReceive1,
    {ok, {_, _, PacketReceived2}} = ResultOfReceive2,
    {ok, {_, _, PacketReceived3}} = ResultOfReceive3,
    {ok, {_, _, PacketReceived4}} = ResultOfReceive4,
    ct:log("PacketReceived1: ~n~s~n", [PacketReceived1]),
    ct:log("PacketReceived2: ~n~s~n", [PacketReceived2]),
    ct:log("PacketReceived3: ~n~s~n", [PacketReceived3]),
    ct:log("PacketReceived4: ~n~s~n", [PacketReceived4]),
    PacketsCombined =
        << PacketReceived1/binary
         , PacketReceived2/binary
         , PacketReceived3/binary
         , PacketReceived4/binary
        >>,
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

        % Processes totals
        , <<"beam_stats.node_foo_host_bar.processes_count_all:3|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_exiting:0|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_garbage_collecting:0|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_registered:1|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_runnable:0|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_running:3|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_suspended:0|g">>
        , <<"beam_stats.node_foo_host_bar.processes_count_waiting:0|g">>

        % Process 1
        , <<"beam_stats.node_foo_host_bar.process_memory.reg_name_foo.0_1_0:15|g">>
        , <<"beam_stats.node_foo_host_bar.process_total_heap_size.reg_name_foo.0_1_0:25|g">>
        , <<"beam_stats.node_foo_host_bar.process_stack_size.reg_name_foo.0_1_0:10|g">>
        , <<"beam_stats.node_foo_host_bar.process_message_queue_len.reg_name_foo.0_1_0:0|g">>

        % Process 2
        , <<"beam_stats.node_foo_host_bar.process_memory.bar_mod-bar_fun-1--NONE--NONE.0_2_0:25|g">>
        , <<"beam_stats.node_foo_host_bar.process_total_heap_size.bar_mod-bar_fun-1--NONE--NONE.0_2_0:35|g">>
        , <<"beam_stats.node_foo_host_bar.process_stack_size.bar_mod-bar_fun-1--NONE--NONE.0_2_0:40|g">>
        , <<"beam_stats.node_foo_host_bar.process_message_queue_len.bar_mod-bar_fun-1--NONE--NONE.0_2_0:5|g">>

        % Process 3
        , <<"beam_stats.node_foo_host_bar.process_memory.baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--0_0_0-0_1_0.0_3_0:25|g">>
        , <<"beam_stats.node_foo_host_bar.process_total_heap_size.baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--0_0_0-0_1_0.0_3_0:35|g">>
        , <<"beam_stats.node_foo_host_bar.process_stack_size.baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--0_0_0-0_1_0.0_3_0:40|g">>
        , <<"beam_stats.node_foo_host_bar.process_message_queue_len.baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--0_0_0-0_1_0.0_3_0:1|g">>
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
