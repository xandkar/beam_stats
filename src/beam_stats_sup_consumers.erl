-module(beam_stats_sup_consumers).

-behaviour(supervisor).

%% API
-export(
    [ start_link/0
    , start_child/2
    ]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(Type, Module, Args),
    {make_ref(), {Module, start_link, Args}, permanent, 5000, Type, [Module]}).

%% ===================================================================
%% API
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_child(Module, Options) ->
    Child = ?CHILD(worker, beam_stats_consumer, [Module, Options]),
    supervisor:start_child(?MODULE, Child).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Consumers = beam_stats_config:consumers(),
    ConsumerSpecToChild =
        fun ({Module, Options}) ->
            ?CHILD(worker, beam_stats_consumer, [Module, Options])
        end,
    Children = lists:map(ConsumerSpecToChild, Consumers),
    SupFlags = {one_for_one, 5, 10},
    {ok, {SupFlags, Children}}.
