-module(proposing_test).

-export([start/1]).

-spec start([atom()]) -> ok.

start(Proplist) ->
    propose(Proplist, 0).

-spec propose([atom()], integer()) -> ok.

propose([X | Xs], V) ->
    send(X, {remote, propose, V}),
    propose(Xs, V + 1);
propose([], _) ->
    ok.

%% private functions

-spec send(atom(), term()) -> term().

send(Destination, Msg) ->
    {remoteapi, Destination} ! Msg.
