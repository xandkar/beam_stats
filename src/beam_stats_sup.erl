-module(beam_stats_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(Type, Module),
    {Module, {Module, start_link, []}, permanent, 5000, Type, [Module]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Children =
        [ ?CHILD(worker     , beam_stats_producer)
        , ?CHILD(supervisor , beam_stats_sup_consumers)
        ],
    SupFlags = {one_for_one, 5, 10},
    {ok, {SupFlags, Children}}.
