-module(beam_stats_producer).

-include("beam_stats.hrl").

-behaviour(gen_server).

%% API
-export(
    [ start_link/0
    ,   subscribe/1
    , unsubscribe/1

    % Force production and distribution. Blocks. Mainly for testing.
    , force_production/0
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

-define(SIGNAL_PRODUCTION , beam_stats_production_signal).
-define(FORCE_PRODUCTION  , beam_stats_force_production).

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

-spec force_production() ->
    {}.
force_production() ->
    gen_server:call(?MODULE, ?FORCE_PRODUCTION).

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

handle_call(?FORCE_PRODUCTION, _From, State1) ->
    State2 = produce(State1),
    {reply, {}, State2}.

handle_info(?SIGNAL_PRODUCTION, #state{}=State1) ->
    State2 = produce(State1),
    ok = schedule_next_production(),
    {noreply, State2}.

%% ============================================================================
%%  Private
%% ============================================================================

-spec produce(state()) ->
    state().
produce(#state{consumers=ConsumersSet, stats_state=StatsState1}=State) ->
    StatsState2 = beam_stats_state:update(StatsState1),
    Stats       = beam_stats_state:export(StatsState2),
    ConsumersList = ordsets:to_list(ConsumersSet),
    ok = push_to_consumers(Stats, ConsumersList),
    State#state{stats_state = StatsState2}.

-spec schedule_first_production() ->
    ok.
schedule_first_production() ->
    _ = self() ! ?SIGNAL_PRODUCTION,
    ok.

-spec schedule_next_production() ->
    ok.
schedule_next_production() ->
    ProductionInterval = beam_stats_config:production_interval(),
    _ = erlang:send_after(ProductionInterval, self(), ?SIGNAL_PRODUCTION),
    ok.

-spec push_to_consumers(beam_stats:t(), [pid()]) ->
    ok.
push_to_consumers(Stats, Consumers) ->
    Push = fun (Consumer) -> gen_server:cast(Consumer, Stats) end,
    lists:foreach(Push, Consumers).
