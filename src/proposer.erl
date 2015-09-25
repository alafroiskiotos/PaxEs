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

-module(proposer).

-behaviour(gen_server).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([prop/1, stop/0]).

%% FSM API
-export([init/1, handle_call/3, handle_cast/2, code_change/3, terminate/2, handle_info/2]).

-record(prop_state, {seq_num :: integer(),
		    proposed_value :: string(),
		    acceptors :: [node()],
		    promises_received :: integer(),
		    promised_values :: [{integer(), string()}]}).

-type prop_state() :: #prop_state{}.

%% Public API

-spec start() -> {ok, pid()}.

start() ->
    gen_server:start({local, ?PROP_NAME}, ?MODULE, [], []).

-spec start_link() -> {ok, pid()}.

start_link() ->
    gen_server:start_link({local, ?PROP_NAME}, ?MODULE, [], []).

%% Client API

-spec prop(string()) -> ok.

prop(Value) ->
    gen_server:cast(?PROP_NAME, {proposer, prepare, Value}).

-spec stop() -> ok.

stop() ->
    gen_server:cast(?PROP_NAME, {mngm, stop}).

%% callback functions

-spec init(term()) -> {ok, prop_state()}.

init(_Args) ->
    %% I am the leader, I should do something
    {{leader, _}, {acceptors, Acceptors}, {learners, _}, _} = utils:read_config(),
    InitState = #prop_state{seq_num = utils:pid_to_num(pid_to_list(self())),
		       proposed_value = "",
		       acceptors = Acceptors,
		       promises_received = 1,
		       promised_values = []},
    {ok, InitState}.

-spec terminate(atom(), prop_state()) -> ok.

terminate(normal, _State) ->
    ok;
terminate(Reason, _State) ->
    io:format("Proposer terminated for ~p~n", [Reason]).

-spec code_change(term() | {down, term()}, prop_state(), term()) -> {ok, prop_state()}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

-spec handle_info(timeout | term(), prop_state()) -> {noreply, prop_state()}.

handle_info(Info, State) ->
    io:format("Proposer -> Hhhmm, unknown request ~p~n", [Info]),
    {noreply, State}.

%% Not implemented yet

-spec handle_call(term(), {pid(), term()}, prop_state()) -> {noreply, prop_state()}.

handle_call(_Request, _From, State) ->
    io:format("No synchronous calls implemented yet~n"),
    {noreply, State}.

-type async_req() :: {propser, prepare, string()} |
		     {proposer, accept_request, nack, integer()} |
		     {proposer, accept_request, integer(), string()} |
		     {mngm, stop} |
		     {mngm, print_state}.

-spec handle_cast(async_req(), prop_state()) -> {noreply, prop_state()} |
						{stop, normal, prop_state()}.

%% Make a proposal to Acceptors
handle_cast({proposer, prepare, Value}, State) ->
    io:format("PROPOSER Proposing value ~p with seq num ~p~n",
	      [Value, State#prop_state.seq_num]),
    %% Broadcast to acceptors
    utils:bcast(proposal_bcast(?ACC_NAME, Value, State#prop_state.seq_num),
		State#prop_state.acceptors),
    NextSeq = State#prop_state.seq_num + 1,
    {noreply, State#prop_state{seq_num = NextSeq, proposed_value = Value}};

%% Proposer received NACK, it should try again with higher sequence number
handle_cast({proposer, accept_request, nack, Seq}, State)
  when Seq == State#prop_state.seq_num - 1 ->
    io:format("PROPOSER received NACK, trying again...~n"),
    utils:bcast(proposal_bcast(?ACC_NAME, State#prop_state.proposed_value,
			      State#prop_state.seq_num),
		State#prop_state.acceptors),
    NextSeq = State#prop_state.seq_num + 1,
    {noreply, State#prop_state{seq_num = NextSeq,
			       promised_values = [],
			      promises_received = 0}};

%% Ignore old NACKs
handle_cast({proposer, accept_request, nack, _Seq}, State) ->
    {noreply, State};

%% Proposer has not received quorum promises yet
handle_cast({proposer, accept_request, Seq, Value}, State)
  when State#prop_state.promises_received < length(State#prop_state.acceptors) / 2 ->
    io:format("PROPOSER has not received quorum yet~n"),
    {noreply, update_promises_state(Seq, Value, State)};

%% Proposer received promises from quorum
handle_cast({proposer, accept_request, Seq, Value}, State) ->
    io:format("PROPOSER has received promises from quorum!~n"),
    NewState = update_promises_state(Seq, Value, State),
    case compute_decide_value(NewState#prop_state.promised_values) of
	%% Decide new value
	{ok, decide} ->
	    io:format("PROPOSER hooray I can decide whatever I want~n"),
	    utils:bcast(accept_bcast(?ACC_NAME, State#prop_state.proposed_value,
				    State#prop_state.seq_num),
			State#prop_state.acceptors),
	    {noreply, State#prop_state{proposed_value = "",
				      promises_received = 0,
				       promised_values = []}};
	%% Value has already been decided
	{ok, Seq, Value} ->
	    io:format("PROPOSER hhhmm I should decide value ~p~n", [Value]),
	    utils:bcast(accept_bcast(?ACC_NAME, Value, State#prop_state.seq_num),
			State#prop_state.acceptors),
	    {noreply, State#prop_state{proposed_value = "",
				      promises_received = 0,
				      promised_values = []}}
    end;

%% Various management calls
handle_cast({mngm, stop}, State) ->
    {stop, normal, State};
handle_cast({mngm, print_state}, State) ->
    io:format("PROPOSER state is ~p~n", [State]),
    {noreply, State}.

%% Private functions

-spec accept_bcast(atom(), string(), integer()) -> function().

accept_bcast(ProcName, Value, Seq) ->
    fun(A) ->
	    gen_server:cast({ProcName, A}, {acceptor, accept, node(), Value, Seq})
    end.

-spec proposal_bcast(atom(), string(), integer()) -> function().

proposal_bcast(ProcName, Value, Seq) ->
    fun(A) ->
	    gen_server:cast({ProcName, A}, {acceptor, prepare, node(), Value, Seq})
    end.

-spec update_promises_state(integer(), string(), prop_state()) -> prop_state().

update_promises_state(Seq, Value, State) ->
    P = State#prop_state.promises_received + 1,
    case Value == "" of
	true ->
	    State#prop_state{promises_received = P};
	false ->
	    Pv = [{Seq, Value} | State#prop_state.promised_values],
	    State#prop_state{promises_received = P, promised_values = Pv}
    end.

-spec compute_decide_value([{integer(), string()}]) ->
				  {ok, decide} | {ok, integer(), string()}.

compute_decide_value(PromisedValues) ->
    case length(PromisedValues) == 0 of
	true ->
	    {ok, decide};
	false ->
	    SortedPv = lists:keysort(1, PromisedValues),
	    {Seq, Value} = lists:last(SortedPv),
	    {ok, Seq, Value}
    end.
