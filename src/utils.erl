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

-module(utils).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([pid_to_num/1, read_config/0, bcast/2]).

-spec pred(char(), integer()) -> integer().

pred(X, Acc) ->
    case X of
	$. ->
	    Acc;
	$> ->
	    Acc;
	N ->
	    Acc + N
    end.

-spec pid_to_num(string()) -> integer().

pid_to_num([_F | Pid]) ->
    lists:foldl(fun(X, Acc) -> pred(X, Acc) end, 0, Pid).

-spec bcast(function(), [node()]) -> ok.

bcast(Fun, Destination) ->
    lists:foreach(Fun, Destination).

-spec read_config() -> {{atom(), node()},
			{atom(), [node()]},
			{atom(), [node()]},
		       {atom(), [node()]}}.

read_config() ->
    {ok, Terms} = file:consult(?CONFIG),
    Leader = lists:keyfind(leader, 1, Terms),
    Acceptors = lists:keyfind(acceptors, 1, Terms),
    Learners = lists:keyfind(learners, 1, Terms),
    Proposers = lists:keyfind(proposers, 1, Terms),
    {Leader, Acceptors, Learners, Proposers}.
