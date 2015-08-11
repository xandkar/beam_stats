-module(beam_stats_producer).

-include("beam_stats.hrl").

-behaviour(gen_server).

%% API
-export(
    [ start_link/0
    ,   subscribe/1
    , unsubscribe/1
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

-record(state,
    { consumers = ordsets:new() :: ordsets:ordset(pid())
    }).

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

%% ============================================================================
%%  gen_server callbacks (unused)
%% ============================================================================

handle_call(_Request, _From, State) ->
    ?METHOD_SHOULD_NOT_BE_USED(handle_call, State).

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
    {ok, #state{consumers=Consumers}}.

handle_cast({subscribe, PID}, #state{consumers=Consumers1}=State) ->
    Consumers2 = ordsets:add_element(PID, Consumers1),
    {noreply, State#state{consumers=Consumers2}};

handle_cast({unsubscribe, PID}, #state{consumers=Consumers1}=State) ->
    Consumers2 = ordsets:del_element(PID, Consumers1),
    {noreply, State#state{consumers=Consumers2}}.

handle_info(?SIGNAL_PRODUCTION, #state{consumers=ConsumersSet}=State) ->
    ConsumersList = ordsets:to_list(ConsumersSet),
    ok = collect_and_push_to_consumers(ConsumersList),
    ok = schedule_next_production(),
    {noreply, State}.

%% ============================================================================
%%  Private
%% ============================================================================

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

-spec collect_and_push_to_consumers([pid()]) ->
    ok.
collect_and_push_to_consumers(Consumers) ->
    BEAMStats = beam_stats:collect(),
    Push = fun (Consumer) -> gen_server:cast(Consumer, BEAMStats) end,
    lists:foreach(Push, Consumers).
