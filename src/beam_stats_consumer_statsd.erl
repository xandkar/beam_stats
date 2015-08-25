-module(beam_stats_consumer_statsd).

-include("include/beam_stats.hrl").
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
    State = #state
        { sock     = none
        , dst_host = DstHost
        , dst_port = DstPort
        , src_port = SrcPort
        },
    {ConsumptionInterval, State}.

-spec consume(beam_stats_consumer:queue(), state()) ->
    state().
consume(Q, #state{}=State1) ->
    Payload = beam_stats_queue_to_binary(Q),
    State2 = try_to_connect_if_no_socket(State1),
    try_to_send(State2, Payload).

-spec terminate(state()) ->
    {}.
terminate(#state{sock=SockOpt}) ->
    ok = hope_option:iter(SockOpt, fun gen_udp:close/1),
    {}.

%% ============================================================================
%% Transport
%% ============================================================================

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

-spec beam_stats_queue_to_binary(beam_stats_consumer:queue()) ->
    binary().
beam_stats_queue_to_binary(Q) ->
    iolist_to_binary([beam_stats_to_bins(B) || B <- queue:to_list(Q)]).

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
        ],
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
