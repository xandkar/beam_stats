-module(beam_stats_consumer_graphite).

-include("include/beam_stats.hrl").

-behaviour(beam_stats_consumer).

-export_type(
    [         option/0
    , connect_option/0
    ]).

-export(
    [ init/1
    , consume/2
    , terminate/1
    ]).

-type connect_option() ::
      {host    , inet:ip_address() | inet:hostname()}
    | {port    , inet:port_number()}
    | {timeout , timeout()}
    .

-type option() ::
      {connect_options      , [connect_option()]}
    | {consumption_interval , non_neg_integer()}
    .

-record(state,
    { connect_options = []   :: [connect_option()]
    , sock            = none :: hope_option:t(Socket :: port())
    }).

-type state() ::
    #state{}.

-define(GRAPHITE_PATH_PREFIX, "beam_stats").

-spec init([option()]) ->
    {non_neg_integer(), state()}.
init(Options) ->
    ConnectOptions      = hope_kv_list:get(Options, connect_options     , []),
    ConsumptionInterval = hope_kv_list:get(Options, consumption_interval, 60000),
    State = #state
        { connect_options = ConnectOptions
        , sock            = none
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
    ok = hope_option:iter(SockOpt, fun gen_tcp:close/1),
    {}.

%% ============================================================================

-spec try_to_send(state(), binary()) ->
    state().
try_to_send(#state{sock=none}=State, _) ->
    io:format("error: socket closed~n"),
    % TODO: Maybe schedule retry?
    State;
try_to_send(#state{sock={some, Sock}}=State, Payload) ->
    case gen_tcp:send(Sock, Payload)
    of  ok ->
            State
    ;   {error, _}=Error ->
            io:format("error: gen_tcp:send/2 failed: ~p~n", [Error]),
            % TODO: Maybe schedule retry?
            ok = gen_tcp:close(Sock),
            State#state{sock=none}
    end.

-spec try_to_connect_if_no_socket(state()) ->
    state().
try_to_connect_if_no_socket(#state{sock={some, _}}=State) ->
    State;
try_to_connect_if_no_socket(#state{sock=none, connect_options=Options}=State) ->
    DefaultHost    = "localhost",
    DefaultPort    = 2003,
    DefaultTimeout = 5000,
    Host    = hope_kv_list:get(Options, host   , DefaultHost),
    Port    = hope_kv_list:get(Options, port   , DefaultPort),
    Timeout = hope_kv_list:get(Options, timeout, DefaultTimeout),
    case gen_tcp:connect(Host, Port, [binary, {active, false}], Timeout)
    of  {ok, Sock} ->
            State#state{sock = {some, Sock}}
    ;   {error, _}=Error ->
            io:format("error: gen_tcp:connect/4 failed: ~p~n", [Error]),
            State#state{sock = none}
    end.

-spec beam_stats_queue_to_binary(beam_stats_consumer:queue()) ->
    binary().
beam_stats_queue_to_binary(Q) ->
    Bins = [beam_stats_to_bin(B) || B <- queue:to_list(Q)],
    iolist_to_binary(Bins).

-spec beam_stats_to_bin(beam_stats:t()) ->
    binary().
beam_stats_to_bin(#beam_stats
    { timestamp = Timestamp
    , node_id   = NodeID
    , memory    = Memory
    }
) ->
    TimestampInt = timestamp_to_integer(Timestamp),
    TimestampBin = integer_to_binary(TimestampInt),
    <<NodeIDBin/binary>> = node_id_to_bin(NodeID),
    PairToBin = make_pair_to_bin(NodeIDBin, TimestampBin),
    MemoryBinPairs = lists:map(fun atom_int_to_bin_bin/1, Memory),
    MemoryBins     = lists:map(PairToBin, MemoryBinPairs),
    AllBins =
        [ MemoryBins
        ],
    iolist_to_binary(AllBins).

-spec timestamp_to_integer(erlang:timestamp()) ->
    non_neg_integer().
timestamp_to_integer({Megaseconds, Seconds, _}) ->
    Megaseconds * 1000000 + Seconds.

-spec make_pair_to_bin(binary(), binary()) ->
    fun(({binary(), binary()}) -> binary()).
make_pair_to_bin(<<NodeID/binary>>, <<TimestampBin/binary>>) ->
    fun ({<<K/binary>>, <<V/binary>>}) ->
        << ?GRAPHITE_PATH_PREFIX
         , "."
         , NodeID/binary
         , "."
         , K/binary
         , " "
         , V/binary
         , " "
         , TimestampBin/binary
         , "\n"
        >>
    end.

-spec node_id_to_bin(node()) ->
    binary().
node_id_to_bin(NodeID) ->
    NodeIDBin = atom_to_binary(NodeID, utf8),
    re:replace(NodeIDBin, "[\@\.]", "_", [global, {return, binary}]).

-spec atom_int_to_bin_bin({atom(), integer()}) ->
    {binary(), binary()}.
atom_int_to_bin_bin({K, V}) ->
    {atom_to_binary(K, latin1), integer_to_binary(V)}.
