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

-record(snapshots,
    { memory     :: [{atom(), non_neg_integer()}]
    , run_queue  :: non_neg_integer()
    }).

-type snapshots() ::
    #snapshots{}.

-record(deltas,
    { reductions :: non_neg_integer()
    }).

-type deltas() ::
    #deltas{}.

-record(totals,
    { io_bytes_in      :: non_neg_integer()
    , io_bytes_out     :: non_neg_integer()
    , context_switches :: non_neg_integer()
    }).

-type totals() ::
    #totals{}.

-record(?MODULE,
    { timestamp       :: erlang:timestamp()
    , node_id         :: atom()
    , snapshots       :: snapshots()  % Current state
    , deltas          :: deltas()     % Accumulated since last check
    , totals_previous :: totals()     % Accumulated since VM start, as of last state
    , totals_current  :: totals()     % Accumulated since VM start, as of this state
    }).

-define(T, #?MODULE).

-opaque t() ::
    ?T{}.

-spec new() ->
    t().
new() ->
    TotalsPrevious = totals_empty(),
    new(TotalsPrevious).

-spec new(TotalsPrevious :: totals()) ->
    t().
new(#totals{}=TotalsPrevious) ->
    ?T
    { timestamp       = os:timestamp()
    , node_id         = erlang:node()
    , snapshots       = snapshots_new()
    , deltas          = deltas_new()
    , totals_previous = TotalsPrevious
    , totals_current  = totals_new()
    }.

-spec update(t()) ->
    t().
update(?T{totals_current=TotalsPrevious}) ->
    new(TotalsPrevious).

-spec export(t()) ->
    beam_stats:t().
export(
    ?T
    { timestamp = Timestamp
    , node_id   = NodeID
    , snapshots =
        #snapshots
        { memory    = Memory
        , run_queue = RunQueue
        }
    , deltas =
        #deltas
        { reductions = Reductions
        }
    , totals_previous =
        #totals
        { io_bytes_in      = PreviousIOBytesIn
        , io_bytes_out     = PreviousIOBytesOut
        , context_switches = PreviousContextSwitches
        }
    , totals_current =
        #totals
        { io_bytes_in      = CurrentIOBytesIn
        , io_bytes_out     = CurrentIOBytesOut
        , context_switches = CurrentContextSwitches
        }
    }
) ->
    #beam_stats
    { timestamp        = Timestamp
    , node_id          = NodeID
    , memory           = Memory
    , io_bytes_in      = CurrentIOBytesIn  - PreviousIOBytesIn
    , io_bytes_out     = CurrentIOBytesOut - PreviousIOBytesOut
    , context_switches = CurrentContextSwitches - PreviousContextSwitches
    , reductions       = Reductions
    , run_queue        = RunQueue
    }.

snapshots_new() ->
    #snapshots
    { memory     = erlang:memory()
    , run_queue  = erlang:statistics(run_queue)
    }.

deltas_new() ->
    {_ReductionsTotal, ReductionsDelta} = erlang:statistics(reductions),
    #deltas
    { reductions = ReductionsDelta
    }.

totals_new() ->
    { {input  , IOBytesIn}
    , {output , IOBytesOut}
    } = erlang:statistics(io),
    {ContextSwitches, 0} = erlang:statistics(context_switches),
    #totals
    { io_bytes_in      = IOBytesIn
    , io_bytes_out     = IOBytesOut
    , context_switches = ContextSwitches
    }.

totals_empty() ->
    #totals
    { io_bytes_in      = 0
    , io_bytes_out     = 0
    , context_switches = 0
    }.
