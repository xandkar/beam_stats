-module(beam_stats_ets_table).

-include("include/beam_stats_ets_table.hrl").

-export_type(
    [ t/0
    , id/0
    ]).

-export(
    [ of_id/1
    , id_to_bin/1
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
    t().
of_id(ID) ->
    WordSize      = beam_stats_source:erlang_system_info(wordsize),
    NumberOfWords = beam_stats_source:ets_info(ID, memory),
    NumberOfBytes = NumberOfWords * WordSize,
    #?MODULE
    { id     = ID
    , name   = beam_stats_source:ets_info(ID, name)
    , size   = beam_stats_source:ets_info(ID, size)
    , memory = NumberOfBytes
    }.

-spec id_to_bin(atom() | ets:tid()) ->
    binary().
id_to_bin(ID) when is_atom(ID) ->
    atom_to_binary(ID, latin1);
id_to_bin(ID) when is_integer(ID) ->
    integer_to_binary(ID).
