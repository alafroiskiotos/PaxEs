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

-module(learner).

-behaviour(gen_server).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Server API
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% Client API
-export([get_value/0]).

-record(lrn_state, {accepted_value :: string()}).

-type lrn_state() :: #lrn_state{}.

%% Client API

-spec get_value() -> term().

get_value() ->
    gen_server:call(?LRN_NAME, {learner, value_request}).

%% Public API

-spec start() -> {ok, pid()}.

start() ->
    gen_server:start({local, ?LRN_NAME}, ?MODULE, [], []).

-spec start_link() -> {ok, pid()}.

start_link() ->
    gen_server:start_link({local, ?LRN_NAME}, ?MODULE, [], []).

%% callback functions

-spec init(term()) -> {ok, lrn_state()}.

init(_Args) ->
    InitState = #lrn_state{accepted_value = ""},
    {ok, InitState}.

-spec terminate(atom(), lrn_state()) -> ok.

terminate(normal, _State) ->
    ok;
terminate(Reason, _State) ->
    io:format("Learner ubnormal termination ~p~n", [Reason]).

-spec code_change(term() | {down, term()}, lrn_state(), term()) -> {ok, lrn_state()}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

-spec handle_info(timeout | term(), lrn_state()) -> {noreply, lrn_state()}.

handle_info(Info, State) ->
    io:format("Learner -> Hhmm, unknown request ~p~n", [Info]),
    {noreply, State}.

-spec handle_call({learner, value_request}, {pid(), term()}, lrn_state()) ->
			 {reply, term(), lrn_state()}.

handle_call({learner, value_request}, From, State) ->
    Reply = {value, State#lrn_state.accepted_value},
    {reply, Reply, State}.

-spec handle_cast({learner, learn, string()}, lrn_state()) -> {noreply, lrn_state()}.

handle_cast({learner, learn, Value}, State) ->
    io:format("Learner, I've learned value: ~p~n", [Value]),
    {noreply, State#lrn_state{accepted_value = Value}}.

