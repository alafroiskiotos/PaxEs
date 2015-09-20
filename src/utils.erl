-module(utils).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([pid_to_num/1, read_config/0, bcast/2, bcast_sync/2]).

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

bcast_sync(Fun, Destination) ->
    lists:foldl(Fun, [], Destination).

bcast(Fun, Destination) ->
    lists:foreach(Fun, Destination).

-spec read_config() -> {{atom(), node()}, {atom(), [node()]}, {atom(), [node()]}}.

read_config() ->
    {ok, Terms} = file:consult(?CONFIG),
    Leader = lists:keyfind(leader, 1, Terms),
    Acceptors = lists:keyfind(acceptors, 1, Terms),
    Learners = lists:keyfind(learners, 1, Terms),
    {Leader, Acceptors, Learners}.
