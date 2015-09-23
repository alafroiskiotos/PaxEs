-module(client_api).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([write/1, read/0, start_remote_api/0, stop_remote_api/0,
	 remote_api/0, manager/0]).

start_remote_api() ->
    register(apimanager, spawn(client_api, manager, [])).

stop_remote_api() ->
    ?REM_NAME ! {remote, mngm, stop},
    unregister(?REM_NAME).

write(Value) ->
    send_async({proposer, prepare, Value}, ?PROP_NAME).

read() ->
    {value, Value} = send_sync({learner, value_request}, ?LRN_NAME),
    Value.


%% private functions
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

send_sync(Msg, Destination) ->
    gen_server:call(Destination, Msg).

send_async(Msg, Destination) ->
    gen_server:cast(Destination, Msg).

remote_api() ->
    receive
	{remote, propose, Value} ->
	    write(Value),
	    remote_api();
	{remote, mngm, stop} ->
	    ok
    end.
