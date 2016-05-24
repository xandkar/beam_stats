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

-define(DEFAULT_HOST    , "localhost").
-define(DEFAULT_PORT    , 2003).
-define(DEFAULT_TIMEOUT , 5000).

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
    Payload = beam_stats_queue_to_iolists(Q),
    State2 = try_to_connect_if_no_socket(State1),
    try_to_send(State2, Payload).

-spec terminate(state()) ->
    {}.
terminate(#state{sock=SockOpt}) ->
    hope_option:iter(SockOpt, fun gen_tcp:close/1).

%% ============================================================================

-spec try_to_send(state(), iolist()) ->
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
            ?log_error("gen_tcp:send(~p, Payload) -> ~p", [Sock, Error]),
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

-spec beam_stats_queue_to_iolists(beam_stats_consumer:queue()) ->
    [iolist()].
beam_stats_queue_to_iolists(Q) ->
    [beam_stats_to_iolist(B) || B <- queue:to_list(Q)].

-spec beam_stats_to_iolist(beam_stats:t()) ->
    [iolist()].
beam_stats_to_iolist(#beam_stats{}=BeamStats) ->
    Msgs = beam_stats_msg_graphite:of_beam_stats(BeamStats),
    lists:map(fun beam_stats_msg_graphite:to_iolist/1, Msgs).
