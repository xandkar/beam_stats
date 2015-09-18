-module(beam_stats_consumer_statsd).

-include("include/beam_stats.hrl").
-include("include/beam_stats_ets_table.hrl").
-include("include/beam_stats_process.hrl").
-include("include/beam_stats_process_ancestry.hrl").
-include("include/beam_stats_processes.hrl").
-include("beam_stats_logging.hrl").

-behaviour(beam_stats_consumer).

-export_type(
    [ option/0
    ]).

%% Consumer interface
-export(
    [ init/1
    , consume/2
    , terminate/1
    ]).

-type option() ::
      {consumption_interval , non_neg_integer()}
    | {dst_host             , inet:ip_address() | inet:hostname()}
    | {dst_port             , inet:port_number()}
    | {src_port             , inet:port_number()}
    | {num_msgs_per_packet  , non_neg_integer()}
    .

-define(DEFAULT_DST_HOST, "localhost").
-define(DEFAULT_DST_PORT, 8125).
-define(DEFAULT_SRC_PORT, 8124).

-type metric_type() ::
    % TODO: Add other metric types
    gauge.

-record(statsd_msg,
    { name  :: binary()
    , value :: non_neg_integer()
    , type  :: metric_type()
    }).

-type statsd_msg() ::
    #statsd_msg{}.

-record(state,
    { sock     :: hope_option:t(gen_udp:socket())
    , dst_host :: inet:ip_address() | inet:hostname()
    , dst_port :: inet:port_number()
    , src_port :: inet:port_number()
    , num_msgs_per_packet :: non_neg_integer()
    }).

-type state() ::
    #state{}.

-define(PATH_PREFIX, "beam_stats").

%% ============================================================================
%% Consumer implementation
%% ============================================================================

-spec init([option()]) ->
    {non_neg_integer(), state()}.
init(Options) ->
    ConsumptionInterval = hope_kv_list:get(Options, consumption_interval, 60000),
    DstHost = hope_kv_list:get(Options, dst_host, ?DEFAULT_DST_HOST),
    DstPort = hope_kv_list:get(Options, dst_port, ?DEFAULT_DST_PORT),
    SrcPort = hope_kv_list:get(Options, src_port, ?DEFAULT_SRC_PORT),
    NumMsgsPerPacket = hope_kv_list:get(Options, num_msgs_per_packet, 10),
    State = #state
        { sock     = none
        , dst_host = DstHost
        , dst_port = DstPort
        , src_port = SrcPort
        , num_msgs_per_packet = NumMsgsPerPacket
        },
    {ConsumptionInterval, State}.

-spec consume(beam_stats_consumer:queue(), state()) ->
    state().
consume(Q, #state{num_msgs_per_packet=NumMsgsPerPacket}=State) ->
    Packets = beam_stats_queue_to_packets(Q, NumMsgsPerPacket),
    lists:foldl(fun try_to_connect_and_send/2, State, Packets).

-spec terminate(state()) ->
    {}.
terminate(#state{sock=SockOpt}) ->
    ok = hope_option:iter(SockOpt, fun gen_udp:close/1),
    {}.

%% ============================================================================
%% Transport
%% ============================================================================

-spec try_to_connect_and_send(binary(), state()) ->
    state().
try_to_connect_and_send(<<Payload/binary>>, #state{}=State1) ->
    State2 = try_to_connect_if_no_socket(State1),
    try_to_send(State2, Payload).

-spec try_to_send(state(), binary()) ->
    state().
try_to_send(#state{sock=none}=State, _) ->
    ?log_error("Sending failed. No socket in state."),
    % TODO: Maybe schedule retry?
    State;
try_to_send(
    #state
    { sock     = {some, Sock}
    , dst_host = DstHost
    , dst_port = DstPort
    }=State,
    Payload
) ->
    case gen_udp:send(Sock, DstHost, DstPort, Payload)
    of  ok ->
            State
    ;   {error, _}=Error ->
            ?log_error(
                "gen_udp:send(~p, ~p, ~p, ~p) -> ~p",
                [Sock, DstHost, DstPort, Error]
            ),
            % TODO: Do something with unsent messages?
            ok = gen_udp:close(Sock),
            State#state{sock=none}
    end.

-spec try_to_connect_if_no_socket(state()) ->
    state().
try_to_connect_if_no_socket(#state{sock={some, _}}=State) ->
    State;
try_to_connect_if_no_socket(#state{sock=none, src_port=SrcPort}=State) ->
    case gen_udp:open(SrcPort)
    of  {ok, Sock} ->
            State#state{sock = {some, Sock}}
    ;   {error, _}=Error ->
            ?log_error("gen_udp:open(~p) -> ~p", [SrcPort, Error]),
            State#state{sock = none}
    end.

%% ============================================================================
%% Serialization
%% ============================================================================

-spec beam_stats_queue_to_packets(beam_stats_consumer:queue(), non_neg_integer()) ->
    [binary()].
beam_stats_queue_to_packets(Q, NumMsgsPerPacket) ->
    MsgBins = lists:append([beam_stats_to_bins(B) || B <- queue:to_list(Q)]),
    MsgBinsChucks = hope_list:divide(MsgBins, NumMsgsPerPacket),
    lists:map(fun erlang:iolist_to_binary/1, MsgBinsChucks).

-spec beam_stats_to_bins(beam_stats:t()) ->
    [binary()].
beam_stats_to_bins(#beam_stats
    { node_id = NodeID
    , memory  = Memory
    , io_bytes_in  = IOBytesIn
    , io_bytes_out = IOBytesOut
    , context_switches = ContextSwitches
    , reductions       = Reductions
    , run_queue        = RunQueue
    , ets              = ETS
    , processes        = Processes
    }
) ->
    NodeIDBin = node_id_to_bin(NodeID),
    Msgs1 =
        [ io_bytes_in_to_msg(IOBytesIn)
        , io_bytes_out_to_msg(IOBytesOut)
        , context_switches_to_msg(ContextSwitches)
        , reductions_to_msg(Reductions)
        , run_queue_to_msg(RunQueue)
        | memory_to_msgs(Memory)
        ]
        ++ ets_to_msgs(ETS)
        ++ procs_to_msgs(Processes),
    Msgs2 = [statsd_msg_add_name_prefix(M, NodeIDBin) || M <- Msgs1],
    [statsd_msg_to_bin(M) || M <- Msgs2].

-spec run_queue_to_msg(non_neg_integer()) ->
    statsd_msg().
run_queue_to_msg(RunQueue) ->
    #statsd_msg
    { name  = <<"run_queue">>
    , value = RunQueue
    , type  = gauge
    }.

-spec reductions_to_msg(non_neg_integer()) ->
    statsd_msg().
reductions_to_msg(Reductions) ->
    #statsd_msg
    { name  = <<"reductions">>
    , value = Reductions
    , type  = gauge
    }.

-spec context_switches_to_msg(non_neg_integer()) ->
    statsd_msg().
context_switches_to_msg(ContextSwitches) ->
    #statsd_msg
    { name  = <<"context_switches">>
    , value = ContextSwitches
    , type  = gauge
    }.

-spec io_bytes_in_to_msg(non_neg_integer()) ->
    statsd_msg().
io_bytes_in_to_msg(IOBytesIn) ->
    #statsd_msg
    { name  = <<"io.bytes_in">>
    , value = IOBytesIn
    , type  = gauge
    }.

-spec io_bytes_out_to_msg(non_neg_integer()) ->
    statsd_msg().
io_bytes_out_to_msg(IOBytesOut) ->
    #statsd_msg
    { name  = <<"io.bytes_out">>
    , value = IOBytesOut
    , type  = gauge
    }.

-spec procs_to_msgs(beam_stats_processes:t()) ->
    [statsd_msg()].
procs_to_msgs(
    #beam_stats_processes
    { individual_stats         = Procs
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
    [ gauge(<<"processes_count_all">>               , CountAll)
    , gauge(<<"processes_count_exiting">>           , CountExiting)
    , gauge(<<"processes_count_garbage_collecting">>, CountGarbageCollecting)
    , gauge(<<"processes_count_registered">>        , CountRegistered)
    , gauge(<<"processes_count_runnable">>          , CountRunnable)
    , gauge(<<"processes_count_running">>           , CountRunning)
    , gauge(<<"processes_count_suspended">>         , CountSuspended)
    , gauge(<<"processes_count_waiting">>           , CountWaiting)
    | lists:append([proc_to_msgs(P) || P <- Procs])
    ].

-spec proc_to_msgs(beam_stats_process:t()) ->
    [statsd_msg()].
proc_to_msgs(
    #beam_stats_process
    { pid               = Pid
    , memory            = Memory
    , total_heap_size   = TotalHeapSize
    , stack_size        = StackSize
    , message_queue_len = MsgQueueLen
    }=Process
) ->
    Origin = beam_stats_process:get_best_known_origin(Process),
    OriginBin = proc_origin_to_bin(Origin),
    PidBin = pid_to_bin(Pid),
    OriginDotPid = <<OriginBin/binary, ".", PidBin/binary>>,
    [ gauge(<<"process_memory."            , OriginDotPid/binary>>, Memory)
    , gauge(<<"process_total_heap_size."   , OriginDotPid/binary>>, TotalHeapSize)
    , gauge(<<"process_stack_size."        , OriginDotPid/binary>>, StackSize)
    , gauge(<<"process_message_queue_len." , OriginDotPid/binary>>, MsgQueueLen)
    ].

-spec proc_origin_to_bin(beam_stats_process:best_known_origin()) ->
    binary().
proc_origin_to_bin({registered_name, Name}) ->
    atom_to_binary(Name, utf8);
proc_origin_to_bin({ancestry, Ancestry}) ->
    #beam_stats_process_ancestry
    { raw_initial_call  = InitCallRaw
    , otp_initial_call  = InitCallOTPOpt
    , otp_ancestors     = AncestorsOpt
    } = Ancestry,
    Blank             = <<"NONE">>,
    InitCallOTPBinOpt = hope_option:map(InitCallOTPOpt   , fun mfa_to_bin/1),
    InitCallOTPBin    = hope_option:get(InitCallOTPBinOpt, Blank),
    AncestorsBinOpt   = hope_option:map(AncestorsOpt     , fun ancestors_to_bin/1),
    AncestorsBin      = hope_option:get(AncestorsBinOpt  , Blank),
    InitCallRawBin    = mfa_to_bin(InitCallRaw),
    << InitCallRawBin/binary
     , "--"
     , InitCallOTPBin/binary
     , "--"
     , AncestorsBin/binary
    >>.

ancestors_to_bin([]) ->
    <<>>;
ancestors_to_bin([A | Ancestors]) ->
    ABin = ancestor_to_bin(A),
    case ancestors_to_bin(Ancestors)
    of  <<>> ->
            ABin
    ;   <<AncestorsBin/binary>> ->
            <<ABin/binary, "-", AncestorsBin/binary>>
    end.

ancestor_to_bin(A) when is_atom(A) ->
    atom_to_binary(A, utf8);
ancestor_to_bin(A) when is_pid(A) ->
    pid_to_bin(A).

pid_to_bin(Pid) ->
    PidList = erlang:pid_to_list(Pid),
    PidBin = re:replace(PidList, "[\.]", "_", [global, {return, binary}]),
             re:replace(PidBin , "[><]", "" , [global, {return, binary}]).

-spec mfa_to_bin(mfa()) ->
    binary().
mfa_to_bin({Module, Function, Arity}) ->
    ModuleBin   = atom_to_binary(Module  , utf8),
    FunctionBin = atom_to_binary(Function, utf8),
    ArityBin    = erlang:integer_to_binary(Arity),
    <<ModuleBin/binary, "-", FunctionBin/binary, "-", ArityBin/binary>>.


-spec gauge(binary(), integer()) ->
    statsd_msg().
gauge(<<Name/binary>>, Value) when is_integer(Value) ->
    #statsd_msg
    { name  = Name
    , value = Value
    , type  = gauge
    }.

-spec ets_to_msgs(beam_stats_ets:t()) ->
    [statsd_msg()].
ets_to_msgs(PerTableStats) ->
    NestedMsgs = lists:map(fun ets_table_to_msgs/1, PerTableStats),
    lists:append(NestedMsgs).

-spec ets_table_to_msgs(beam_stats_ets_table:t()) ->
    [statsd_msg()].
ets_table_to_msgs(#beam_stats_ets_table
    { id     = ID
    , name   = Name
    , size   = Size
    , memory = Memory
    }
) ->
    IDBin   = beam_stats_ets_table:id_to_bin(ID),
    NameBin = atom_to_binary(Name, latin1),
    NameAndID = <<NameBin/binary, ".", IDBin/binary>>,
    SizeMsg =
        #statsd_msg
        { name  = <<"ets_table.size.", NameAndID/binary>>
        , value = Size
        , type  = gauge
        },
    MemoryMsg =
        #statsd_msg
        { name  = <<"ets_table.memory.", NameAndID/binary>>
        , value = Memory
        , type  = gauge
        },
    [SizeMsg, MemoryMsg].

-spec memory_to_msgs([{atom(), non_neg_integer()}]) ->
    [statsd_msg()].
memory_to_msgs(Memory) ->
    [memory_component_to_statsd_msg(MC) || MC <- Memory].

-spec memory_component_to_statsd_msg({atom(), non_neg_integer()}) ->
    statsd_msg().
memory_component_to_statsd_msg({MemType, MemSize}) when MemSize >= 0 ->
    MemTypeBin = atom_to_binary(MemType, latin1),
    #statsd_msg
    { name  = <<"memory.", MemTypeBin/binary>>
    , value = MemSize
    , type  = gauge
    }.

-spec statsd_msg_add_name_prefix(statsd_msg(), binary()) ->
    statsd_msg().
statsd_msg_add_name_prefix(#statsd_msg{name=Name1}=Msg, <<NodeID/binary>>) ->
    Prefix = <<?PATH_PREFIX, ".", NodeID/binary, ".">>,
    Name2 = <<Prefix/binary, Name1/binary>>,
    Msg#statsd_msg{name=Name2}.

-spec statsd_msg_to_bin(statsd_msg()) ->
    binary().
statsd_msg_to_bin(
    #statsd_msg
    { name  = <<Name/binary>>
    , value = Value
    , type  = Type = gauge
    }
) when Value >= 0 ->
    TypeBin = metric_type_to_bin(Type),
    ValueBin = integer_to_binary(Value),
    << Name/binary
     , ":"
     , ValueBin/binary
     , "|"
     , TypeBin/binary
     , "\n"
    >>.

-spec metric_type_to_bin(metric_type()) ->
    binary().
metric_type_to_bin(gauge) ->
    <<"g">>.

-spec node_id_to_bin(node()) ->
    binary().
node_id_to_bin(NodeID) ->
    NodeIDBin = atom_to_binary(NodeID, utf8),
    re:replace(NodeIDBin, "[\@\.]", "_", [global, {return, binary}]).
