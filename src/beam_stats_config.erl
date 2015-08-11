-module(beam_stats_config).

-export(
    [ production_interval/0
    , consumers/0
    ]).

-define(APP, beam_stats).

%% ============================================================================
%%  API
%% ============================================================================

-spec production_interval() ->
    non_neg_integer().
production_interval() ->
    get_env(production_interval).

-spec consumers() ->
    [{ConsumerModule :: atom(), ConsumerDefinedOptionsData :: term()}].
consumers() ->
    get_env(consumers).

%% ============================================================================
%%  Internal
%% ============================================================================

-spec get_env(atom()) ->
    term().
get_env(Key) ->
    {ok, Value} = application:get_env(?APP, Key),
    Value.
