-module(beam_stats_producer).

-behaviour(gen_server).

%% API
-export(
    [ start_link/0
    ,   subscribe/1
    , unsubscribe/1

    % For testing
    , sync_produce_consume/0
    ]).

%% gen_server callbacks
-export(
    [ init/1
    , handle_call/3
    , handle_cast/2
    , handle_info/2
    , terminate/2
    , code_change/3
    ]).

%% ============================================================================
%% Internal data
%% ============================================================================

-define(PRODUCE_SYNC  , produce_sync).
-define(PRODUCE_ASYNC , produce_async).

-record(state,
    { consumers = ordsets:new() :: ordsets:ordset(pid())
    , stats_state :: beam_stats_state:t()
    }).

-type state() ::
    #state{}.

%% ============================================================================
%%  API
%% ============================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec subscribe(pid()) ->
    ok.
subscribe(PID) ->
    gen_server:cast(?MODULE, {subscribe, PID}).

-spec unsubscribe(pid()) ->
    ok.
unsubscribe(PID) ->
    gen_server:cast(?MODULE, {unsubscribe, PID}).

-spec sync_produce_consume() ->
    {}.
sync_produce_consume() ->
    {} = gen_server:call(?MODULE, ?PRODUCE_SYNC).

%% ============================================================================
%%  gen_server callbacks (unused)
%% ============================================================================

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

%% ============================================================================
%%  gen_server callbacks
%% ============================================================================

init([]) ->
    ok = schedule_first_production(),
    Consumers = ordsets:new(),
    StatsState = beam_stats_state:new(),
    {ok, #state{consumers=Consumers, stats_state=StatsState}}.

handle_cast({subscribe, PID}, #state{consumers=Consumers1}=State) ->
    Consumers2 = ordsets:add_element(PID, Consumers1),
    {noreply, State#state{consumers=Consumers2}};

handle_cast({unsubscribe, PID}, #state{consumers=Consumers1}=State) ->
    Consumers2 = ordsets:del_element(PID, Consumers1),
    {noreply, State#state{consumers=Consumers2}}.

handle_call(?PRODUCE_SYNC, _From, State1) ->
    State2 = produce_sync(State1),
    {reply, {}, State2}.

handle_info(?PRODUCE_ASYNC, #state{}=State1) ->
    State2 = produce_async(State1),
    ok = schedule_next_production(),
    {noreply, State2}.

%% ============================================================================
%%  Private
%% ============================================================================

-spec produce_sync(state()) ->
    state().
produce_sync(#state{}=State) ->
    produce(State, fun beam_stats_consumer:consume_sync/2).

-spec produce_async(state()) ->
    state().
produce_async(#state{}=State) ->
    produce(State, fun beam_stats_consumer:consume_async/2).

-spec produce(state(), fun((pid(), term()) -> ok)) ->
    state().
produce(
    #state
    { consumers   = ConsumersSet
    , stats_state = StatsState1
    }=State,
    MsgSendFun
) ->
    StatsState2 = beam_stats_state:update(StatsState1),
    Stats       = beam_stats_state:export(StatsState2),
    ConsumersList = ordsets:to_list(ConsumersSet),
    Send = fun (Consumer) -> MsgSendFun(Consumer, Stats) end,
    ok = lists:foreach(Send, ConsumersList),
    State#state{stats_state = StatsState2}.

-spec schedule_first_production() ->
    ok.
schedule_first_production() ->
    _ = self() ! ?PRODUCE_ASYNC,
    ok.

-spec schedule_next_production() ->
    ok.
schedule_next_production() ->
    ProductionInterval = beam_stats_config:production_interval(),
    _ = erlang:send_after(ProductionInterval, self(), ?PRODUCE_ASYNC),
    ok.
