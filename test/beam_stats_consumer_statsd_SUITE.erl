-module(beam_stats_consumer_statsd_SUITE).

-export(
    [ all/0
    , groups/0
    ]).

%% Test cases
-export(
    [ t_beam_stats_to_bins/1
    , t_memory_component_to_statsd_msg/1
    , t_statsd_msg_add_name_prefix/1
    , t_statsd_msg_to_bin/1
    , t_node_id_to_bin/1
    ]).

-define(statsd_module, beam_stats_consumer_statsd).
-define(GROUP, ?statsd_module).

%% ============================================================================
%% Common Test callbacks
%% ============================================================================

all() ->
    [{group, ?GROUP}].

groups() ->
    Tests =
        [ t_beam_stats_to_bins
        , t_memory_component_to_statsd_msg
        , t_statsd_msg_add_name_prefix
        , t_statsd_msg_to_bin
        , t_node_id_to_bin
        ],
    Properties = [],
    [{?GROUP, Properties, Tests}].

%% =============================================================================
%%  Test cases
%% =============================================================================

t_beam_stats_to_bins(_Cfg) ->
    ?statsd_module:ct_test__beam_stats_to_bins(_Cfg).

t_memory_component_to_statsd_msg(_Cfg) ->
    ?statsd_module:ct_test__memory_component_to_statsd_msg(_Cfg).

t_statsd_msg_add_name_prefix(_Cfg) ->
    ?statsd_module:ct_test__statsd_msg_add_name_prefix(_Cfg).

t_statsd_msg_to_bin(_Cfg) ->
    ?statsd_module:ct_test__statsd_msg_to_bin(_Cfg).

t_node_id_to_bin(_Cfg) ->
    ?statsd_module:ct_test__node_id_to_bin(_Cfg).
