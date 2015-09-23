-module(client_api).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([write/1, read/0, start_remote_api/0, stop_remote_api/0,
	 remote_api/0, manager/0]).

-spec start_remote_api() -> true.

start_remote_api() ->
    register(apimanager, spawn(client_api, manager, [])).

-spec stop_remote_api() -> true.

stop_remote_api() ->
    ?REM_NAME ! {remote, mngm, stop},
    unregister(?REM_NAME).

-spec write(string()) -> ok.

write(Value) ->
    send_async({proposer, prepare, Value}, ?PROP_NAME).

-spec read() -> string().

read() ->
    {value, Value} = send_sync({learner, value_request}, ?LRN_NAME),
    Value.


%% private functions

-spec manager() -> ok.

manager() ->
    process_flag(trap_exit, true),
    register(?REM_NAME, spawn_link(client_api, remote_api, [])),
    receive
	{mngm, manager, stop} ->
	    ok;
	{'EXIT', Pid, normal} ->
	    unregister(apimanager),
	    ok;
	{'EXIT', Pid, shutdown} ->
	    unregister(apimanager),
	    ok;
	{'EXIT', Pid, _Reason} ->
	    io:format("Process ~p crashed, restarting...~n", [Pid]),
	    manager()
    end.

-spec send_sync(term(), atom()) -> term().

send_sync(Msg, Destination) ->
    gen_server:call(Destination, Msg).

-spec send_async(term(), atom()) -> ok.

send_async(Msg, Destination) ->
    gen_server:cast(Destination, Msg).

-spec remote_api() -> ok.

remote_api() ->
    receive
	{remote, propose, Value} ->
	    write(Value),
	    remote_api();
	{remote, mngm, stop} ->
	    ok
    end.
