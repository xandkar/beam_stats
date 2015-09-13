-module(beam_stats_process).

-include("include/beam_stats_process.hrl").

-export_type(
    [ t/0
    , status/0
    ]).

-export(
    [ of_pid/1
    ]).

-type status() ::
      exiting
    | garbage_collecting
    | runnable
    | running
    | suspended
    | waiting
    .

-define(T, #?MODULE).

-type t() ::
    ?T{}.

-spec of_pid(pid()) ->
    t().
of_pid(Pid) ->
    Dict = pid_info_exn(Pid, dictionary),
    ?T
    { pid               = Pid
    , registered_name   = pid_info_opt(Pid, registered_name)
    , raw_initial_call  = pid_info_exn(Pid, initial_call)
    , otp_initial_call  = hope_kv_list:get(Dict, '$initial_call')
    , otp_ancestors     = hope_kv_list:get(Dict, '$ancestors')
    , status            = pid_info_exn(Pid, status)
    , memory            = pid_info_exn(Pid, memory)
    , total_heap_size   = pid_info_exn(Pid, total_heap_size)
    , stack_size        = pid_info_exn(Pid, stack_size)
    , message_queue_len = pid_info_exn(Pid, message_queue_len)
    }.

pid_info_exn(Pid, Key) ->
    {some, Value} = pid_info_opt(Pid, Key),
    Value.

pid_info_opt(Pid, Key) ->
    case {Key, erlang:process_info(Pid, Key)}
    of  {registered_name, []}           -> none
    ;   {_              , {Key, Value}} -> {some, Value}
    end.
