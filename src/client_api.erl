-module(client_api).

-include_lib("PaxEs/include/paxos_def.hrl").

-export([write/1, read/0]).

write(Value) ->
    send_async({proposer, prepare, Value}, ?PROP_NAME).

read() ->
    {value, Value} = send_sync({learner, value_request}, ?LRN_NAME),
    Value.

%% private functions
send_sync(Msg, Destination) ->
    gen_server:call(Destination, Msg).

send_async(Msg, Destination) ->
    gen_server:cast(Destination, Msg).
