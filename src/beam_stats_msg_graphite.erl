-module(beam_stats_msg_graphite).

-include("include/beam_stats.hrl").
-include("include/beam_stats_ets_table.hrl").
-include("include/beam_stats_msg_graphite.hrl").

-export_type(
    [ t/0
    ]).

-export(
    [ of_beam_stats/1
    %, to_bin/1
    ]).

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec of_beam_stats(beam_stats:t()) ->
    [t()].
of_beam_stats(#beam_stats{node_id=NodeID}=BeamStats) ->
    NodeIDBin = node_id_to_bin(NodeID),
    of_beam_stats(BeamStats, NodeIDBin).

-spec of_beam_stats(beam_stats:t(), binary()) ->
    [t()].
of_beam_stats(#beam_stats
    { timestamp = Timestamp
    , node_id   = _
    , memory    = Memory
    % TODO: Handle the rest of data points
    , io_bytes_in      = IOBytesIn
    , io_bytes_out     = IOBytesOut
    , context_switches = ContextSwitches
    , reductions       = Reductions
    , run_queue        = RunQueue
    , ets              = ETS
    , processes        = _Processes
    },
    <<NodeID/binary>>
) ->
    Ts = Timestamp,
    N = NodeID,
    [ cons([N, <<"io">>               , <<"bytes_in">> ], IOBytesIn      , Ts)
    , cons([N, <<"io">>               , <<"bytes_out">>], IOBytesOut     , Ts)
    , cons([N, <<"context_switches">>                  ], ContextSwitches, Ts)
    , cons([N, <<"reductions">>                        ], Reductions     , Ts)
    , cons([N, <<"run_queue">>                         ], RunQueue       , Ts)
    | of_memory(Memory, NodeID, Ts)
    ]
    ++ of_ets(ETS, NodeID, Ts)
    .

-spec of_memory([{atom(), non_neg_integer()}], binary(), erlang:timestamp()) ->
    [t()].
of_memory(Memory, <<NodeID/binary>>, Timestamp) ->
    ComponentToMessage =
        fun ({Key, Value}) ->
            KeyBin = atom_to_binary(Key, latin1),
            cons([NodeID, <<"memory">>, KeyBin], Value, Timestamp)
        end,
    lists:map(ComponentToMessage, Memory).

-spec of_ets(beam_stats_ets_table:t(), binary(), erlang:timestamp()) ->
    [t()].
of_ets(PerTableStats, <<NodeID/binary>>, Timestamp) ->
    OfEtsTable = fun (Table) -> of_ets_table(Table, NodeID, Timestamp) end,
    NestedMsgs = lists:map(OfEtsTable, PerTableStats),
    lists:append(NestedMsgs).

-spec of_ets_table(beam_stats_ets_table:t(), binary(), erlang:timestamp()) ->
    [t()].
of_ets_table(#beam_stats_ets_table
    { id     = ID
    , name   = Name
    , size   = Size
    , memory = Memory
    },
    <<NodeID/binary>>,
    Timestamp
) ->
    IDBin     = beam_stats_ets_table:id_to_bin(ID),
    NameBin   = atom_to_binary(Name, latin1),
    NameAndID = [NameBin, IDBin],
    [ cons([NodeID, <<"ets_table">>, <<"size">>   | NameAndID], Size  , Timestamp)
    , cons([NodeID, <<"ets_table">>, <<"memory">> | NameAndID], Memory, Timestamp)
    ].

-spec cons([binary()], integer(), erlang:timestamp()) ->
    t().
cons(Path, Value, Timestamp) ->
    ?T
    { path      = Path
    , value     = Value
    , timestamp = Timestamp
    }.

-spec node_id_to_bin(node()) ->
    binary().
node_id_to_bin(NodeID) ->
    NodeIDBin = atom_to_binary(NodeID, utf8),
    re:replace(NodeIDBin, "[\@\.]", "_", [global, {return, binary}]).
