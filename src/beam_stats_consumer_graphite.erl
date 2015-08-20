-module(beam_stats_consumer_graphite).

-include("include/beam_stats.hrl").
-include("beam_stats_logging.hrl").

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
      {consumption_interval , non_neg_integer()}
    | {host                 , inet:ip_address() | inet:hostname()}
    | {port                 , inet:port_number()}
    | {timeout              , timeout()}
    .

-record(state,
    { sock    = none :: hope_option:t(Socket :: port())
    , host           :: inet:ip_address() | inet:hostname()
    , port           :: inet:port_number()
    , timeout        :: timeout()
    }).

-type state() ::
    #state{}.

-define(GRAPHITE_PATH_PREFIX, "beam_stats").
-define(DEFAULT_HOST        , "localhost").
-define(DEFAULT_PORT        , 2003).
-define(DEFAULT_TIMEOUT     , 5000).

-spec init([option()]) ->
    {non_neg_integer(), state()}.
init(Options) ->
    Get = fun (Key, Default) -> hope_kv_list:get(Options, Key, Default) end,
    ConsumptionInterval = Get(consumption_interval, 60000),
    State = #state
        { sock    = none
        , host    = Get(host    , ?DEFAULT_HOST)
        , port    = Get(port    , ?DEFAULT_PORT)
        , timeout = Get(timeout , ?DEFAULT_TIMEOUT)
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
    ?log_error("Sending failed. No socket in state."),
    % TODO: Maybe schedule retry?
    State;
try_to_send(#state{sock={some, Sock}}=State, Payload) ->
    case gen_tcp:send(Sock, Payload)
    of  ok ->
            State
    ;   {error, _}=Error ->
            ?log_error("gen_tcp:send(~p, ~p) -> ~p", [Sock, Payload, Error]),
            % TODO: Maybe schedule retry?
            ok = gen_tcp:close(Sock),
            State#state{sock=none}
    end.

-spec try_to_connect_if_no_socket(state()) ->
    state().
try_to_connect_if_no_socket(#state{sock={some, _}}=State) ->
    State;
try_to_connect_if_no_socket(
    #state
    { sock    = none
    , host    = Host
    , port    = Port
    , timeout = Timeout
    }=State
) ->
    Options = [binary, {active, false}],
    case gen_tcp:connect(Host, Port, Options, Timeout)
    of  {ok, Sock} ->
            State#state{sock = {some, Sock}}
    ;   {error, _}=Error ->
            ?log_error(
                "gen_tcp:connect(~p, ~p, ~p, ~p) -> ~p",
                [Host, Port, Options, Timeout, Error]
            ),
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
