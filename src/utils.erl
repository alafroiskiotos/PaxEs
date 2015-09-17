-module(utils).

-include("paxos_def.hrl").

-export([pid_to_num/1, bcast_proposal/4, read_config/0]).

pred(X, Acc) ->
    case X of
	$. ->
	    Acc;
	$> ->
	    Acc;
	N ->
	    Acc + N
    end.

pid_to_num([_F | Pid]) ->
    lists:foldl(fun(X, Acc) -> pred(X, Acc) end, 0, Pid).
    
bcast_proposal(Acceptors, ProcName, Value, Seq) ->
    lists:map(fun(A) -> gen_fsm:send_event({ProcName, A}, {prepare, acceptor, Value, Seq}) end, Acceptors).

read_config() ->
    {ok, Dir} = file:get_cwd(),
    io:format("pwd ~p~n", [Dir]),
    io:format("config: ~p~n", [?CONFIG]),
    {ok, Terms} = file:consult(?CONFIG),
    Leader = lists:keyfind(leader, 1, Terms),
    Peers = lists:keyfind(peers, 1, Terms),
    {Leader, Peers}.
