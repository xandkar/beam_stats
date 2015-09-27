-module(beam_stats_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    DeltasServer = beam_stats_delta:start(),
    beam_stats_sup:start_link(DeltasServer).

stop(_State) ->
    ok.
