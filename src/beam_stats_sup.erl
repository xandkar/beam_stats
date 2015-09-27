-module(beam_stats_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(Type, Module, Args),
    {Module, {Module, start_link, Args}, permanent, 5000, Type, [Module]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(DeltasServer) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, DeltasServer).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(DeltasServer) ->
    Children =
    [ ?CHILD(worker     , beam_stats_producer     , [DeltasServer])
    , ?CHILD(supervisor , beam_stats_sup_consumers, [])
    ],
    SupFlags = {one_for_one, 5, 10},
    {ok, {SupFlags, Children}}.
