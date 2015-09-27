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
    [ t_full_cycle/1
    ]).

-define(GROUP, beam_stats_consumer_statsd).

%% ============================================================================
%% Common Test callbacks
%% ============================================================================

all() ->
    [{group, ?GROUP}].

groups() ->
    Tests =
        [ t_full_cycle
        ],
    Properties = [],
    [{?GROUP, Properties, Tests}].

%% ============================================================================
%%  Test cases
%% ============================================================================

t_full_cycle(_Cfg) ->
    meck:new(beam_stats_source),
    _BEAMStatsExpected = meck_expect_beam_stats(),

    {ok,[hope,beam_stats]} = application:ensure_all_started(beam_stats),
    ct:log("beam_stats started~n"),
    ServerPort = 8125,
    {ok, ServerSocket} = gen_udp:open(ServerPort, [binary, {active, false}]),
    ct:log("UDP server started started~n"),
    {ok, _} = beam_stats_consumer:add(beam_stats_consumer_statsd,
        [ {consumption_interval , 60000}
        , {dst_host             , "localhost"}
        , {dst_port             , ServerPort}
        , {src_port             , 8124}
        , {num_msgs_per_packet  , 10}
        ]
    ),
    ct:log("consumer added~n"),
    _ = meck_expect_beam_stats(
        % Double the original values, so that deltas will equal originals after
        % 1 update of new beam_stats_state:t()
        [ {io_bytes_in      , 6}
        , {io_bytes_out     , 14}
        , {context_switches , 10}
        , {reductions       , 18}
        ]
    ),
    ct:log("meck_expect_beam_stats ok~n"),
    {} = beam_stats_producer:sync_produce_consume(),
    ct:log("produced and consumed~n"),
    ok = application:stop(beam_stats),
    ct:log("beam_stats stopped~n"),

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
        [ <<"beam_stats_v0.node_foo_host_bar.io.bytes_in:3|g">>
        , <<"beam_stats_v0.node_foo_host_bar.io.bytes_out:7|g">>
        , <<"beam_stats_v0.node_foo_host_bar.context_switches:5|g">>
        , <<"beam_stats_v0.node_foo_host_bar.reductions:9|g">>
        , <<"beam_stats_v0.node_foo_host_bar.run_queue:17|g">>
        , <<"beam_stats_v0.node_foo_host_bar.memory.mem_type_foo:1|g">>
        , <<"beam_stats_v0.node_foo_host_bar.memory.mem_type_bar:2|g">>
        , <<"beam_stats_v0.node_foo_host_bar.memory.mem_type_baz:3|g">>
        , <<"beam_stats_v0.node_foo_host_bar.ets_table.size.foo.NAMED:5|g">>
        , <<"beam_stats_v0.node_foo_host_bar.ets_table.memory.foo.NAMED:40|g">>
        , <<"beam_stats_v0.node_foo_host_bar.ets_table.size.bar.TID:16|g">>
        , <<"beam_stats_v0.node_foo_host_bar.ets_table.memory.bar.TID:128|g">>

        % Processes totals
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_all:4|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_exiting:0|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_garbage_collecting:0|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_registered:1|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_runnable:0|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_running:3|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_suspended:0|g">>
        , <<"beam_stats_v0.node_foo_host_bar.processes_count_waiting:1|g">>

        % Process 1
        , <<"beam_stats_v0.node_foo_host_bar.process_memory.named--reg_name_foo:15|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_total_heap_size.named--reg_name_foo:25|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_stack_size.named--reg_name_foo:10|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_message_queue_len.named--reg_name_foo:0|g">>

        % Process 2
        , <<"beam_stats_v0.node_foo_host_bar.process_memory.spawned-via--bar_mod-bar_fun-1--NONE--NONE:25|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_total_heap_size.spawned-via--bar_mod-bar_fun-1--NONE--NONE:35|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_stack_size.spawned-via--bar_mod-bar_fun-1--NONE--NONE:40|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_message_queue_len.spawned-via--bar_mod-bar_fun-1--NONE--NONE:5|g">>

        % Process 3 and 4, aggregated by origin
        , <<"beam_stats_v0.node_foo_host_bar.process_memory.spawned-via--baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--PID-PID:30|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_total_heap_size.spawned-via--baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--PID-PID:45|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_stack_size.spawned-via--baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--PID-PID:55|g">>
        , <<"beam_stats_v0.node_foo_host_bar.process_message_queue_len.spawned-via--baz_mod-baz_fun-3--baz_otp_mod-baz_otp_fun-2--PID-PID:1|g">>
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
    [] = lists:foldl(RemoveExpectedFromReceived, MsgsReceived, MsgsExpected),
    meck:unload(beam_stats_source).

meck_expect_beam_stats() ->
    meck_expect_beam_stats([]).

meck_expect_beam_stats(Overrides) ->
    IOBytesIn       = hope_kv_list:get(Overrides, io_bytes_in , 3),
    IOBytesOut      = hope_kv_list:get(Overrides, io_bytes_out, 7),
    ContextSwitches = hope_kv_list:get(Overrides, context_switches, 5),
    Reductions      = hope_kv_list:get(Overrides, reductions, 9),
    Pid0 = list_to_pid("<0.0.0>"),
    Pid1 = list_to_pid("<0.1.0>"),
    Pid2 = list_to_pid("<0.2.0>"),
    Pid3 = list_to_pid("<0.3.0>"),
    Pid4 = list_to_pid("<0.4.0>"),
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
    Process4 =
        #beam_stats_process
        { pid               = Pid4
        , registered_name   = none
        , ancestry =
              #beam_stats_process_ancestry
              { raw_initial_call  = {baz_mod, baz_fun, 3}
              , otp_initial_call  = {some, {baz_otp_mod, baz_otp_fun, 2}}
              , otp_ancestors     = {some, [Pid0, Pid1]}
              }
        , status            = waiting
        , memory            = 5
        , total_heap_size   = 10
        , stack_size        = 15
        , message_queue_len = 0
        },
    Processes =
        #beam_stats_processes
        { individual_stats =
            [ Process1
            , Process2
            , Process3
            , Process4
            ]
        , count_all                = 4
        , count_exiting            = 0
        , count_garbage_collecting = 0
        , count_registered         = 1
        , count_runnable           = 0
        , count_running            = 3
        , count_suspended          = 0
        , count_waiting            = 1
        },
    ETSTableStatsFoo =
        #beam_stats_ets_table
        { id     = foo
        , name   = foo
        , size   = 5
        , memory = 40
        },
    ETSTableStatsBarA =
        #beam_stats_ets_table
        { id     = 37
        , name   = bar
        , size   = 8
        , memory = 64
        },
    ETSTableStatsBarB =
        #beam_stats_ets_table
        { id     = 38
        , name   = bar
        , size   = 8
        , memory = 64
        },
    meck:expect(beam_stats_source, erlang_memory,
        fun () -> [{mem_type_foo, 1}, {mem_type_bar, 2}, {mem_type_baz, 3}] end),
    meck:expect(beam_stats_source, erlang_node,
        fun () -> 'node_foo@host_bar' end),
    meck:expect(beam_stats_source, erlang_registered,
        fun () -> [reg_name_foo] end),
    meck:expect(beam_stats_source, erlang_statistics,
        fun (io              ) -> {{input, IOBytesIn}, {output, IOBytesOut}}
        ;   (context_switches) -> {ContextSwitches, 0}
        ;   (reductions      ) -> {Reductions, undefined} % 2nd element is unused
        ;   (run_queue       ) -> 17
        end
    ),
    meck:expect(beam_stats_source, ets_all,
        fun () -> [foo, 37, 38] end),
    meck:expect(beam_stats_source, erlang_system_info,
        fun (wordsize) -> 8 end),
    meck:expect(beam_stats_source, ets_info,
        fun (foo, memory) -> 5
        ;   (foo, name  ) -> foo
        ;   (foo, size  ) -> 5

        ;   (37 , memory) -> 8
        ;   (37 , name  ) -> bar
        ;   (37 , size  ) -> 8

        ;   (38 , memory) -> 8
        ;   (38 , name  ) -> bar
        ;   (38 , size  ) -> 8
        end
    ),
    meck:expect(beam_stats_source, erlang_processes,
        fun () -> [Pid1, Pid2, Pid3, Pid4] end),
    meck:expect(beam_stats_source, os_timestamp,
        fun () -> {1, 2, 3} end),
    meck:expect(beam_stats_source, erlang_process_info,
        fun (P, K) when P == Pid1 ->
                case K
                of  dictionary        -> {K, []}
                ;   initial_call      -> {K, {foo_mod, foo_fun, 2}}
                ;   registered_name   -> {K, reg_name_foo}
                ;   status            -> {K, running}
                ;   memory            -> {K, 15}
                ;   total_heap_size   -> {K, 25}
                ;   stack_size        -> {K, 10}
                ;   message_queue_len -> {K, 0}
                end
        ;   (P, K) when P == Pid2 ->
                case K
                of  dictionary        -> {K, []}
                ;   initial_call      -> {K, {bar_mod, bar_fun, 1}}
                ;   registered_name   -> []
                ;   status            -> {K, running}
                ;   memory            -> {K, 25}
                ;   total_heap_size   -> {K, 35}
                ;   stack_size        -> {K, 40}
                ;   message_queue_len -> {K, 5}
                end
        ;   (P, K) when P == Pid3 ->
                Dict =
                    [ {'$initial_call', {baz_otp_mod, baz_otp_fun, 2}}
                    , {'$ancestors'   , [Pid0, Pid1]}
                    ],
                case K
                of  dictionary        -> {K, Dict}
                ;   initial_call      -> {K, {baz_mod, baz_fun, 3}}
                ;   registered_name   -> []
                ;   status            -> {K, running}
                ;   memory            -> {K, 25}
                ;   total_heap_size   -> {K, 35}
                ;   stack_size        -> {K, 40}
                ;   message_queue_len -> {K, 1}
                end
        ;   (P, K) when P == Pid4 ->
                Dict =
                    [ {'$initial_call', {baz_otp_mod, baz_otp_fun, 2}}
                    , {'$ancestors'   , [Pid0, Pid1]}
                    ],
                case K
                of  dictionary        -> {K, Dict}
                ;   initial_call      -> {K, {baz_mod, baz_fun, 3}}
                ;   registered_name   -> []
                ;   status            -> {K, waiting}
                ;   memory            -> {K, 5}
                ;   total_heap_size   -> {K, 10}
                ;   stack_size        -> {K, 15}
                ;   message_queue_len -> {K, 0}
                end
        end
    ),
    #beam_stats
    { timestamp = {1, 2, 3}
    , node_id   = 'node_foo@host_bar'
    , memory    = [{mem_type_foo, 1}, {mem_type_bar, 2}, {mem_type_baz, 3}]
    , io_bytes_in  = IOBytesIn
    , io_bytes_out = IOBytesOut
    , context_switches = ContextSwitches
    , reductions       = 9
    , run_queue        = 17
    , ets              = [ETSTableStatsFoo, ETSTableStatsBarA, ETSTableStatsBarB]
    , processes        = Processes
    }.
