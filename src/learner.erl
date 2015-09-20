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

%% Client API
get_value() ->
    gen_server:call(?LRN_NAME, {learner, value_request}).

%% Public API
start() ->
    gen_server:start({local, ?LRN_NAME}, ?MODULE, [], []).

start_link() ->
    gen_server:start_link({local, ?LRN_NAME}, ?MODULE, [], []).

%% callback functions
init(_Args) ->
    InitState = #lrn_state{accepted_value = ""},
    {ok, InitState}.

terminate(normal, _State) ->
    ok;
terminate(Reason, _State) ->
    io:format("Learner ubnormal termination ~p~n", [Reason]).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

handle_info(Info, State) ->
    io:format("Learner -> Hhmm, unknown request ~p~n", [Info]),
    {noreply, State}.


handle_call({learner, value_request}, From, State) ->
    Reply = {value, State#lrn_state.accepted_value},
    {reply, Reply, State}.

handle_cast({learner, learn, Value}, State) ->
    io:format("Learner, I've learned value: ~p~n", [Value]),
    {noreply, State#lrn_state{accepted_value = Value}}.

