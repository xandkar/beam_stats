-module(beam_stats_consumer_csv).

-include("include/beam_stats.hrl").

-behaviour(beam_stats_consumer).

-export_type(
    [ option/0
    ]).

-export(
    [ init/1
    , consume/2
    , terminate/1
    ]).

-type option() ::
      {path                 , file:filename()}
    | {consumption_interval , erlang:time()}
    .

-record(state,
    { path        :: file:filename()
    , file = none :: hope_option:t(file:io_device())
    }).

-type state() ::
    #state{}.

-spec init([option()]) ->
    {erlang:time(), state()}.
init(Options) ->
    ConsumptionInterval = hope_kv_list:get(Options, consumption_interval, 60000),
    {some, Path} = hope_kv_list:get(Options, path),
    State = #state
        { path = Path
        , file = none
        },
    {ConsumptionInterval, State}.

-spec consume(beam_stats_consumer:queue(), state()) ->
    state().
consume(Q, #state{}=State1) ->
    Payload = beam_stats_queue_to_binary(Q),
    State2 = try_to_open_if_no_file(State1),
    try_to_write(State2, Payload).

-spec terminate(state()) ->
    {}.
terminate(#state{file=FileOpt}) ->
    ok = hope_option:iter(FileOpt, fun file:close/1),
    {}.

%% ============================================================================

-spec try_to_write(state(), binary()) ->
    state().
try_to_write(#state{file=none, path=Path}=State, _) ->
    io:format("error: file closed: ~s~n", [Path]),
    State;
try_to_write(#state{file={some, File}}=State, Payload) ->
    case file:write(File, Payload)
    of  ok ->
            State
    ;   {error, _}=Error ->
            io:format("error: file:write/2 failed: ~p~n", [Error]),
            % TODO: Maybe schedule retry?
            ok = file:close(File),
            State#state{file=none}
    end.

-spec try_to_open_if_no_file(state()) ->
    state().
try_to_open_if_no_file(#state{file={some, _}}=State) ->
    State;
try_to_open_if_no_file(#state{file=none, path=Path}=State) ->
    case file:open(Path, [append])
    of  {ok, File} ->
            State#state{file = {some, File}}
    ;   {error, _}=Error ->
            io:format("error: file:open/2 failed: ~p~n", [Error]),
            State#state{file = none}
    end.

-spec beam_stats_queue_to_binary(beam_stats_consumer:queue()) ->
    binary().
beam_stats_queue_to_binary(BEAMStatsQ) ->
    Bins = [beam_stats_to_bin(B) || B <- queue:to_list(BEAMStatsQ)],
    iolist_to_binary(Bins).


-spec beam_stats_to_bin(beam_stats:t()) ->
    binary().
beam_stats_to_bin(#beam_stats
    { timestamp = Timestamp
    , node_id   = NodeID
    , memory    = Memory
    }
) ->
    <<TimestampBin/binary>> = timestamp_to_bin(Timestamp),
    <<NodeIDBin/binary>> = node_id_to_bin(NodeID),
    PairToBin = make_pair_to_bin(NodeIDBin, TimestampBin),
    MemoryBinPairs = lists:map(fun atom_int_to_bin_bin/1, Memory),
    MemoryBins     = lists:map(PairToBin, MemoryBinPairs),
    AllBins =
        [ MemoryBins
        ],
    iolist_to_binary(AllBins).

-spec timestamp_to_bin(erlang:timestamp()) ->
    binary().
timestamp_to_bin(Timestamp) ->
    TimestampFloat = timestamp_to_float(Timestamp),
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:now_to_local_time(Timestamp),
    SecondsFloat = Sec + (TimestampFloat - trunc(TimestampFloat)),
    Fmt2Digits = "~2.10.0b",
    FmtDate = string:join(["~b"      , Fmt2Digits, Fmt2Digits], "-"),
    FmtTime = string:join([Fmt2Digits, Fmt2Digits, "~9..0f"  ], ":"),
    Separator = " ",
    Fmt = FmtDate ++ Separator ++ FmtTime,
    IOList = io_lib:format(Fmt, [Year, Month, Day, Hour, Min, SecondsFloat]),
    iolist_to_binary(IOList).

-spec timestamp_to_float(erlang:timestamp()) ->
    float().
timestamp_to_float({ComponentMega, ComponentWhole, ComponentMicro}) ->
    OneMillion = 1000000,
    TotalWholeSeconds = ComponentMega * OneMillion + ComponentWhole,
    TotalMicroSeconds = (TotalWholeSeconds * OneMillion) + ComponentMicro,
    TotalMicroSeconds / OneMillion.

-spec make_pair_to_bin(binary(), binary()) ->
    fun(({binary(), binary()}) -> binary()).
make_pair_to_bin(<<NodeID/binary>>, <<TimestampBin/binary>>) ->
    fun ({<<K/binary>>, <<V/binary>>}) ->
        << TimestampBin/binary
         , "|"
         , NodeID/binary
         , "|"
         , K/binary
         , "|"
         , V/binary
         , "\n"
        >>
    end.

-spec node_id_to_bin(node()) ->
    binary().
node_id_to_bin(NodeID) ->
    atom_to_binary(NodeID, utf8).

-spec atom_int_to_bin_bin({atom(), integer()}) ->
    {binary(), binary()}.
atom_int_to_bin_bin({K, V}) ->
    {atom_to_binary(K, latin1), integer_to_binary(V)}.
