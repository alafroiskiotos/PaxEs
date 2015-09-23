-module(proposing_test).

-export([start/1]).

start(Proplist) ->
    propose(Proplist, 0).

propose([X | Xs], V) ->
    send(X, {remote, propose, V}),
    propose(Xs, V + 1);
propose([], _) ->
    ok.

%% private functions
send(Destination, Msg) ->
    {remoteapi, Destination} ! Msg.
