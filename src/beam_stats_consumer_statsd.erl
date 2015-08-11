-module(beam_stats_consumer_statsd).

-include("include/beam_stats.hrl").

-behaviour(beam_stats_consumer).

-export_type(
    [ option/0
    ]).

-export(
    [ init/1
    , consume/2
    , terminate/1
    ]).

-type option() ::
      {consumption_interval , erlang:time()}
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
    {erlang:time(), state()}.
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
    io:format("error: socket closed~n"),
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
            io:format("error: gen_udp:send/4 failed: ~p~n", [Error]),
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
            io:format("error: gen_udp:open/1 failed: ~p~n", [Error]),
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
    }
) ->
    NodeIDBin = node_id_to_bin(NodeID),
    Msgs1 = memory_to_msgs(Memory),
    Msgs2 = [statsd_msg_add_name_prefix(M, NodeIDBin) || M <- Msgs1],
    [statsd_msg_to_bin(M) || M <- Msgs2].

-spec memory_to_msgs(erlang:memory()) ->
    [statsd_msg()].
memory_to_msgs(Memory) ->
    [memory_component_to_statsd_msg(MC) || MC <- Memory].

-spec memory_component_to_statsd_msg({erlang:memory_type(), non_neg_integer()}) ->
    statsd_msg().
memory_component_to_statsd_msg({MemType, MemSize}) when MemSize >= 0 ->
    #statsd_msg
    { name  = atom_to_binary(MemType, latin1)
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
