-module(client_api).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([write/1, read/0, stop_remote_api/0, init/0, manager/1, remote_api/1]).

-record(cl_state, {proposer :: atom(),
		  learner :: atom()}).

-type cl_state() :: #cl_state{}.

-spec stop_remote_api() -> true.

stop_remote_api() ->
    ?REM_NAME ! {remote, mngm, stop},
    unregister(?REM_NAME).

init() ->
    random:seed(erlang:monotonic_time()),
    {_, _, {learners, Learners}, {proposers, Proposers}} = utils:read_config(),
    Lrand = random:uniform(length(Learners)),
    Prand = random:uniform(length(Proposers)),
    State = #cl_state{proposer = lists:nth(Prand, Proposers),
		      learner = lists:nth(Lrand, Learners)},
    start_remote_api(State).

-spec write(string()) -> ok.

write(Value) ->
    ?REM_NAME ! {remote, propose, Value},
    ok.

-spec read() -> string() | ok.

read() ->
    ?REM_NAME ! {remote, read, self()},
    receive
	{value, Value} ->
	    Value;
	_ ->
	    ok
    end.
    
%% private functions
-spec start_remote_api(cl_state()) -> true.

start_remote_api(State) ->
    register(apimanager, spawn(client_api, manager, [State])).

write_pr(Value, Proposer) ->
    send_async({?PROP_NAME, prepare, Value}, {?PROP_NAME, Proposer}).

read_pr(Learner, From) ->
    Reply = send_sync({?LRN_NAME, value_request}, {?LRN_NAME, Learner}),
    From ! Reply.

-spec manager(cl_state()) -> ok.

manager(State) ->
    process_flag(trap_exit, true),
    register(?REM_NAME, spawn_link(client_api, remote_api, [State])),
    receive
	{mngm, manager, stop} ->
	    ok;
	{'EXIT', _Pid, normal} ->
	    unregister(apimanager),
	    ok;
	{'EXIT', _Pid, shutdown} ->
	    unregister(apimanager),
	    ok;
	{'EXIT', Pid, _Reason} ->
	    io:format("Process ~p crashed, restarting...~n", [Pid]),
	    manager(State)
    end.

-spec send_sync(term(), atom()) -> term().

send_sync(Msg, Destination) ->
    gen_server:call(Destination, Msg).

-spec send_async(term(), atom()) -> ok.

send_async(Msg, Destination) ->
    gen_server:cast(Destination, Msg).

-spec remote_api(cl_state()) -> ok.

remote_api(State) ->
    receive
	{remote, propose, Value} ->
	    write_pr(Value, State#cl_state.proposer),
	    remote_api(State);
	{remote, read, From} ->
	    read_pr(State#cl_state.learner, From),
	    remote_api(State);
	{remote, mngm, stop} ->
	    ok
    end.
