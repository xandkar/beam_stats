-module(beam_stats_consumer).

-include("include/beam_stats.hrl").
-include(        "beam_stats.hrl").

-behaviour(gen_server).

-export_type(
    [ queue/0
    ]).

%% Public API
-export(
    [ add/2
    ]).

%% Internal API
-export(
    [ start_link/2
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

-type queue() ::
    queue:queue(beam_stats:t()).

%% ============================================================================
%%  Consumer interface
%% ============================================================================

-callback init(Options :: term()) ->
    {ConsumptionInterval :: non_neg_integer(), State :: term()}.

-callback consume(queue(), State) ->
    State.

-callback terminate(State :: term()) ->
    {}.

%% ============================================================================
%% Internal data
%% ============================================================================

-define(SIGNAL_CONSUMPTION , beam_stats_consumption_signal).

-record(state,
    { consumer_module      :: atom()
    , consumer_state       :: term()
    , consumption_interval :: non_neg_integer()
    , beam_stats_queue     :: queue()
    }).

%% ============================================================================
%%  Public API
%% ============================================================================

-spec add(atom(), term()) ->
    supervisor:startchild_ret().
add(ConsumerModule, ConsumerOptions) ->
    beam_stats_sup_consumers:start_child(ConsumerModule, ConsumerOptions).

%% ============================================================================
%%  Internal API
%% ============================================================================

start_link(ConsumerModule, ConsumerOptions) ->
    GenServerModule = ?MODULE,
    GenServerOpts   = [],
    InitArgs        = [ConsumerModule, ConsumerOptions],
    gen_server:start_link(GenServerModule, InitArgs, GenServerOpts).

%% ============================================================================
%%  gen_server callbacks (unused)
%% ============================================================================

handle_call(_Request, _From, State) ->
    ?METHOD_SHOULD_NOT_BE_USED(handle_call, State).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ============================================================================
%%  gen_server callbacks
%% ============================================================================

init([ConsumerModule, ConsumerOptions]) ->
    {ConsumptionInterval, ConsumerState} = ConsumerModule:init(ConsumerOptions),
    State = #state
        { consumer_module      = ConsumerModule
        , consumer_state       = ConsumerState
        , consumption_interval = ConsumptionInterval
        , beam_stats_queue     = queue:new()
        },
    ok = beam_stats_producer:subscribe(self()),
    ok = schedule_first_consumption(),
    {ok, State}.

terminate(_Reason, _State) ->
    ok = beam_stats_producer:unsubscribe(self()).

handle_cast(#beam_stats{}=BEAMStats, #state{beam_stats_queue=Q1}=State) ->
    Q2 = queue:in(BEAMStats, Q1),
    {noreply, State#state{beam_stats_queue = Q2}}.

handle_info(
    ?SIGNAL_CONSUMPTION,
    #state
    { consumer_module      = ConsumerModule
    , consumer_state       = ConsumerState
    , consumption_interval = ConsumptionInterval
    , beam_stats_queue     = Q
    }=State1
) ->
    State2 = State1#state
        { consumer_state   = ConsumerModule:consume(Q, ConsumerState)
        , beam_stats_queue = queue:new()
        },
    ok = schedule_next_consumption(ConsumptionInterval),
    {noreply, State2}.

%% ============================================================================
%%  Internal
%% ============================================================================

-spec schedule_first_consumption() ->
    ok.
schedule_first_consumption() ->
    _ = self() ! ?SIGNAL_CONSUMPTION,
    ok.

-spec schedule_next_consumption(non_neg_integer()) ->
    ok.
schedule_next_consumption(Time) ->
    _ = erlang:send_after(Time, self(), ?SIGNAL_CONSUMPTION),
    ok.
