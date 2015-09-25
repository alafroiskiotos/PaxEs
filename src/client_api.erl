%% Copyright (C) 2015
%% Antonios Kouzoupis <kouzoupis.ant@gmail.com>
%%
%% This file is part of PaxEs.
%%
%% PaxEs is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%%
%% PaxEs is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with PaxEs. If not, see <http://www.gnu.org/licenses/>.

-module(client_api).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([write/1, read/0, stop/0, start/0, manager/1, remote_api/1]).

-record(cl_state, {proposer :: atom(),
		  learner :: atom()}).

-type cl_state() :: #cl_state{}.

-spec start() -> true.

start() ->
    random:seed(erlang:monotonic_time()),
    {_, _, {learners, Learners}, {proposers, Proposers}} = utils:read_config(),
    Lrand = random:uniform(length(Learners)),
    Prand = random:uniform(length(Proposers)),
    State = #cl_state{proposer = lists:nth(Prand, Proposers),
		      learner = lists:nth(Lrand, Learners)},
    start_remote_api(State).

-spec stop() -> true.

stop() ->
    ?REM_NAME ! {remote, mngm, stop},
    unregister(?REM_NAME).

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

-spec write(string(), atom()) -> ok.

write(Value, Proposer) ->
    send_async({?PROP_NAME, prepare, Value}, {?PROP_NAME, Proposer}),
    ok.

-spec read(atom(), pid()) -> {value, string()}.

read(Learner, From) ->
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

-spec send_sync(term(), {atom(), atom()}) -> term().

send_sync(Msg, Destination) ->
    gen_server:call(Destination, Msg).

-spec send_async(term(), {atom(), atom()}) -> ok.

send_async(Msg, Destination) ->
    gen_server:cast(Destination, Msg).

-spec remote_api(cl_state()) -> ok.

remote_api(State) ->
    receive
	{remote, propose, Value} ->
	    write(Value, State#cl_state.proposer),
	    remote_api(State);
	{remote, read, From} ->
	    read(State#cl_state.learner, From),
	    remote_api(State);
	{remote, mngm, stop} ->
	    ok
    end.
