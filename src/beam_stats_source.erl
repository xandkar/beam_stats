-module(beam_stats_source).

-export(
    [ erlang_is_process_alive/1
    , erlang_memory/0
    , erlang_node/0
    , erlang_process_info/2
    , erlang_processes/0
    , erlang_registered/0
    , erlang_statistics/1
    , erlang_system_info/1
    , ets_all/0
    , ets_info/2
    , os_timestamp/0
    ]).

erlang_is_process_alive(Pid) ->
    erlang:is_process_alive(Pid).

erlang_memory() ->
    erlang:memory().

erlang_node() ->
    erlang:node().

erlang_process_info(Pid, Key) ->
    erlang:process_info(Pid, Key).

erlang_processes() ->
    erlang:processes().

erlang_registered() ->
    erlang:registered().

erlang_statistics(Key) ->
    erlang:statistics(Key).

erlang_system_info(Key) ->
    erlang:system_info(Key).

ets_all() ->
    ets:all().

ets_info(Table, Key) ->
    ets:info(Table, Key).

os_timestamp() ->
    os:timestamp().
