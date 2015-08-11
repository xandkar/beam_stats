-module(beam_stats_consumer_statsd_SUITE).

-export(
    [ all/0
    , groups/0
    ]).

%% Test cases
-export(
    [ ct_test__beam_stats_to_bins/1
    , ct_test__memory_component_to_statsd_msg/1
    , ct_test__statsd_msg_add_name_prefix/1
    , ct_test__statsd_msg_to_bin/1
    , ct_test__node_id_to_bin/1
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
        [ ct_test__beam_stats_to_bins
        , ct_test__memory_component_to_statsd_msg
        , ct_test__statsd_msg_add_name_prefix
        , ct_test__statsd_msg_to_bin
        , ct_test__node_id_to_bin
        ],
    Properties = [],
    [{?GROUP, Properties, Tests}].

%% =============================================================================
%%  Test cases
%% =============================================================================

ct_test__beam_stats_to_bins(_Cfg) ->
    ?statsd_module:ct_test__beam_stats_to_bins(_Cfg).

ct_test__memory_component_to_statsd_msg(_Cfg) ->
    ?statsd_module:ct_test__memory_component_to_statsd_msg(_Cfg).

ct_test__statsd_msg_add_name_prefix(_Cfg) ->
    ?statsd_module:ct_test__statsd_msg_add_name_prefix(_Cfg).

ct_test__statsd_msg_to_bin(_Cfg) ->
    ?statsd_module:ct_test__statsd_msg_to_bin(_Cfg).

ct_test__node_id_to_bin(_Cfg) ->
    ?statsd_module:ct_test__node_id_to_bin(_Cfg).
