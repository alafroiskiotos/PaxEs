-module(utils).

-export([pid_to_num/1, bcast_proposal/3]).

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
    
bcast_proposal(Acceptors, Value, Seq) ->
    lists:map(fun(A) -> gen_fsm:send_event(A, {prepare, acceptor, Value, Seq}) end, Acceptors).

