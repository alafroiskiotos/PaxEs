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

-module(acceptor).

-behaviour(gen_server).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([print_state/0]).

%% Server API
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(acc_state, {accepted_value :: string(),
		   learners :: [node()],
		   last_promise :: integer(),
		   leader :: node()}).

-type acc_state() :: #acc_state{}.

%% Public API

-spec start() -> {ok, pid()}.

start() ->
    gen_server:start({local, ?ACC_NAME}, ?MODULE, [], []).

-spec start_link() -> {ok, pid()}.

start_link() ->
    gen_server:start_link({local, ?ACC_NAME}, ?MODULE, [], []).

%% Client API

-spec print_state() -> ok.

print_state() ->
    gen_server:cast(?ACC_NAME, {mngm, print_state}).

%% callback functions

-spec init(term()) -> {ok, acc_state()}.

init(_Args) ->
    {{leader, Leader}, {acceptors, _}, {learners, Learners}, _} = utils:read_config(),
    InitState = #acc_state{accepted_value = "",
			  learners = Learners,
			  last_promise = -1,
			   leader = Leader},
    {ok, InitState}.

-spec terminate(atom(), acc_state()) -> ok.

terminate(normal, _State) ->
    ok;
terminate(Reason, _State) ->
    io:format("Acceptor ubnormal termination ~p~n", [Reason]).

-spec code_change(term() | {down, term()}, acc_state(), term()) -> {ok, acc_state()}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

-spec handle_info(timeout | term(), acc_state()) -> {noreply, acc_state()}.

handle_info(Info, State) ->
    io:format("Acceptor -> Hhhmm, unknown request ~p~n", [Info]),
    {noreply, State}.

-spec handle_call(term(), {pid(), term()}, acc_state()) -> {noreply, acc_state()}.

handle_call(_Request, _From, State) ->
    io:format("No synchronous calls implemented yet~n"),
    {noreply, State}.

-type async_req() :: {acceptor, prepare, term(), string(), integer()} |
		     {acceptor, accept, term(), string(), integer()} |
		     {mngm, atom()}.

-spec handle_cast(async_req(), acc_state()) -> {noreply, acc_state()}.

%% Value is here just for debugging
handle_cast({acceptor, prepare, From, Value, Seq}, State)
  when Seq > State#acc_state.last_promise ->
    io:format("ACCEPTOR received proposal with higher sequence number, promise!~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n",
	      [Value, Seq, State#acc_state.last_promise]),

    gen_server:cast({?PROP_NAME, From}, {proposer, accept_request,
					State#acc_state.last_promise,
					State#acc_state.accepted_value}),
    {noreply, State#acc_state{last_promise = Seq}};

%% I should send NACK here
handle_cast({acceptor, prepare, From, Value, Seq}, State) ->
    io:format("ACCEPTOR received proposal with lesser seq number, ignore!~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n",
	      [Value, Seq, State#acc_state.last_promise]),
    gen_server:cast({?PROP_NAME, From}, {proposer, accept_request, nack, Seq}),
    {noreply, State};

handle_cast({acceptor, accept, _From, Value, Seq}, State)
  when Seq >= State#acc_state.last_promise ->
    io:format("Accepted value ~p~n", [Value]),
    %% I should send a message to learners about the outcome
    %% and acknowledge to Proposer
    utils:bcast(learner_bcast(?LRN_NAME, Value), State#acc_state.learners),
    {noreply, State#acc_state{accepted_value = Value}};

handle_cast({mngm, stop}, State) ->
    {stop, normal, State};
handle_cast({mngm, reset}, State) ->
    NewState = #acc_state{accepted_value = "",
			  learners = State#acc_state.learners,
			  last_promise = -1,
			  leader = State#acc_state.leader},
    {noreply, NewState};
handle_cast({mngm, new_round}, State) ->
    {noreply, State#acc_state{accepted_value = ""}};
handle_cast({mngm, print_state}, State) ->
    io:format("State: ~p~n", [State]),
    {noreply, State};
handle_cast(_Request, State) ->
    io:format("Not implemented yet~n"),
    {noreply, State}.

%% Private functions

-spec learner_bcast(atom(), string()) -> function().

learner_bcast(ProcName, Value) ->
    fun(A) ->
	    gen_server:cast({ProcName, A}, {learner, learn, Value})
    end.
