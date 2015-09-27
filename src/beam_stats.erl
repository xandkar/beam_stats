-module(beam_stats).

-include("include/beam_stats.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ collect/1
    ]).

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec collect(beam_stats_delta:t()) ->
    t().
collect(DeltasServer) ->
    { {io_bytes_in  , DeltaOfIOBytesIn}
    , {io_bytes_out , DeltaOfIOBytesOut}
    } = beam_stats_delta:of_io(DeltasServer),
    ?T
    { timestamp        = beam_stats_source:os_timestamp()
    , node_id          = beam_stats_source:erlang_node()
    , memory           = beam_stats_source:erlang_memory()
    , io_bytes_in      = DeltaOfIOBytesIn
    , io_bytes_out     = DeltaOfIOBytesOut
    , context_switches = beam_stats_delta:of_context_switches(DeltasServer)
    , reductions       = beam_stats_delta:of_reductions(DeltasServer)
    , run_queue        = beam_stats_source:erlang_statistics(run_queue)
    , ets              = beam_stats_ets:collect()
    , processes        = beam_stats_processes:collect()
    }.
