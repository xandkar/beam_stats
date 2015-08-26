-module(beam_stats_consumer).

-include("include/beam_stats.hrl").

-behaviour(gen_server).

-export_type(
    [ queue/0
    ]).

%% Public API
-export(
    [ add/2
    , consume_sync/2
    , consume_async/2
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

-define(FLUSH         , flush).
-define(CONSUME_SYNC  , consume_sync).
-define(CONSUME_ASYNC , consume_async).

-record(state,
    { consumer_module      :: module()
    , consumer_state       :: term()
    , consumption_interval :: non_neg_integer()
    , beam_stats_queue     :: queue()
    }).

-type state() ::
    #state{}.

%% ============================================================================
%%  Public API
%% ============================================================================

-spec add(module(), term()) ->
    supervisor:startchild_ret().
add(ConsumerModule, ConsumerOptions) ->
    beam_stats_sup_consumers:start_child(ConsumerModule, ConsumerOptions).

-spec consume_sync(pid(), beam_stats:t()) ->
    {}.
consume_sync(PID, #beam_stats{}=BEAMStats) ->
    {} = gen_server:call(PID, {?CONSUME_SYNC, BEAMStats}).

-spec consume_async(pid(), beam_stats:t()) ->
    {}.
consume_async(PID, #beam_stats{}=BEAMStats) ->
    ok = gen_server:cast(PID, {?CONSUME_ASYNC, BEAMStats}),
    {}.

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
    ok = schedule_first_flush(),
    {ok, State}.

terminate(_Reason, _State) ->
    ok = beam_stats_producer:unsubscribe(self()).

handle_call({?CONSUME_SYNC, #beam_stats{}=BEAMStats}, _, #state{}=State1) ->
    State2 = consume_one(BEAMStats, State1),
    {reply, {}, State2}.

handle_cast({?CONSUME_ASYNC, #beam_stats{}=BEAMStats}, #state{}=State1) ->
    State2 = enqueue(BEAMStats, State1),
    {noreply, State2}.

handle_info(?FLUSH, #state{consumption_interval=ConsumptionInterval}=State1) ->
    State2 = consume_all_queued(State1),
    ok = schedule_next_flush(ConsumptionInterval),
    {noreply, State2}.

%% ============================================================================
%%  Internal
%% ============================================================================

-spec consume_one(beam_stats:t(), state()) ->
    state().
consume_one(#beam_stats{}=BEAMStats, #state{}=State1) ->
    Q = queue:in(BEAMStats, queue:new()),
    consume(Q, State1).

-spec consume_all_queued(state()) ->
    state().
consume_all_queued(#state{beam_stats_queue=Q}=State1) ->
    State2 = consume(Q, State1),
    State2#state{beam_stats_queue = queue:new()}.

-spec consume(queue(), state()) ->
    state().
consume(
    Q,
    #state
    { consumer_module  = ConsumerModule
    , consumer_state   = ConsumerState
    }=State
) ->
    State#state{consumer_state = ConsumerModule:consume(Q, ConsumerState)}.

-spec enqueue(beam_stats:t(), state()) ->
    state().
enqueue(#beam_stats{}=BEAMStats, #state{beam_stats_queue=Q}=State) ->
    State#state{beam_stats_queue = queue:in(BEAMStats, Q)}.

-spec schedule_first_flush() ->
    ok.
schedule_first_flush() ->
    _ = self() ! ?FLUSH,
    ok.

-spec schedule_next_flush(non_neg_integer()) ->
    ok.
schedule_next_flush(Time) ->
    _ = erlang:send_after(Time, self(), ?FLUSH),
    ok.
