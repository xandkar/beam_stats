-module(beam_stats_ets_table).

-include("include/beam_stats_ets_table.hrl").

-export_type(
    [ t/0
    , id/0
    ]).

-export(
    [ of_id/1
    ]).

-type id() ::
      atom()
    | ets:tid()
    % integer() is just a workaround, to let us mock ets:tid(), which is
    % opaque, but represented as an integer, without Dialyzer complaining.
    | integer()
    .

-type t() ::
    #?MODULE{}.

-spec of_id(id()) ->
    hope_opt:t(t()).
of_id(ID) ->
    Name          = beam_stats_source:ets_info(ID, name),
    Size          = beam_stats_source:ets_info(ID, size),
    NumberOfWords = beam_stats_source:ets_info(ID, memory),
    case lists:member(undefined, [Name, Size, NumberOfWords]) of
        true -> % Table went away.
            none;
        false ->
            WordSize      = beam_stats_source:erlang_system_info(wordsize),
            NumberOfBytes = NumberOfWords * WordSize,
            T =
                #?MODULE
                { id     = ID
                , name   = Name
                , size   = Size
                , memory = NumberOfBytes
                },
            {some, T}
    end.
