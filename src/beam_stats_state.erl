-module(beam_stats_state).

-include("include/beam_stats.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ new/0
    , update/1
    , export/1
    ]).

-record(?MODULE,
    { timestamp             :: erlang:timestamp()
    , node_id               :: atom()
    , memory                :: [{atom(), non_neg_integer()}]

    , previous_io_bytes_in  :: non_neg_integer()
    , previous_io_bytes_out :: non_neg_integer()
    , current_io_bytes_in   :: non_neg_integer()
    , current_io_bytes_out  :: non_neg_integer()

    , previous_context_switches :: non_neg_integer()
    ,  current_context_switches :: non_neg_integer()

    , reductions                :: non_neg_integer()
    }).

-define(T, #?MODULE).

-opaque t() ::
    ?T{}.

-spec new() ->
    t().
new() ->
    { {input  , CurrentIOBytesIn}
    , {output , CurrentIOBytesOut}
    } = erlang:statistics(io),
    {CurrentContextSwitches, 0} = erlang:statistics(context_switches),
    {_ReductionsTotal, ReductionsDelta} = erlang:statistics(reductions),
    ?T
    { timestamp             = os:timestamp()
    , node_id               = erlang:node()
    , memory                = erlang:memory()
    , previous_io_bytes_in  = 0
    , previous_io_bytes_out = 0
    , current_io_bytes_in   = CurrentIOBytesIn
    , current_io_bytes_out  = CurrentIOBytesOut
    , previous_context_switches = 0
    ,  current_context_switches = CurrentContextSwitches
    , reductions                = ReductionsDelta
    }.

-spec update(t()) ->
    t().
update(?T
    { previous_io_bytes_in  = PreviousIOBytesIn
    , previous_io_bytes_out = PreviousIOBytesOut
    , previous_context_switches = PreviousContextSwitches
    }
) ->
    { {input  , CurrentIOBytesIn}
    , {output , CurrentIOBytesOut}
    } = erlang:statistics(io),
    {CurrentContextSwitches, 0} = erlang:statistics(context_switches),
    {_ReductionsTotal, ReductionsDelta} = erlang:statistics(reductions),
    ?T
    { timestamp             = os:timestamp()
    , node_id               = erlang:node()
    , memory                = erlang:memory()
    , previous_io_bytes_in  = PreviousIOBytesIn
    , previous_io_bytes_out = PreviousIOBytesOut
    , current_io_bytes_in   = CurrentIOBytesIn
    , current_io_bytes_out  = CurrentIOBytesOut
    , previous_context_switches = PreviousContextSwitches
    ,  current_context_switches = CurrentContextSwitches
    , reductions                = ReductionsDelta
    }.

-spec export(t()) ->
    beam_stats:t().
export(
    ?T
    { timestamp             = Timestamp
    , node_id               = NodeID
    , memory                = Memory
    , previous_io_bytes_in  = PreviousIOBytesIn
    , previous_io_bytes_out = PreviousIOBytesOut
    , current_io_bytes_in   = CurrentIOBytesIn
    , current_io_bytes_out  = CurrentIOBytesOut
    , previous_context_switches = PreviousContextSwitches
    ,  current_context_switches = CurrentContextSwitches
    , reductions                = Reductions
    }
) ->
    #beam_stats
    { timestamp    = Timestamp
    , node_id      = NodeID
    , memory       = Memory
    , io_bytes_in  = CurrentIOBytesIn  - PreviousIOBytesIn
    , io_bytes_out = CurrentIOBytesOut - PreviousIOBytesOut
    , context_switches = CurrentContextSwitches - PreviousContextSwitches
    , reductions       = Reductions
    }.
