-module(paxos).

-behaviour(gen_fsm).

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([prop/2, print_state/0]).

%% FSM API
-export([init/1, handle_event/3, code_change/4, terminate/3, handle_info/3]).

%% FSM States
-export([prepare/2]).

-record(state, {seq_num = 0,
	       value}).

-define(NAME, paxos).

%% Public API
start() ->
    gen_fsm:start({local, ?NAME}, ?MODULE, [], []).

start_link() ->
    gen_fsm:start_link({local, ?NAME}, ?MODULE, [], []).

%% Client API
prop(Value, Seq) ->
    gen_fsm:send_event(?NAME, {propose, Value, Seq}).

print_state() ->
    gen_fsm:send_all_state_event(?NAME, {mngm, current_state}).

%% FSM API
init(_Name) ->
    Init = #state{value = 'None'},
    {ok, prepare, Init}.

prepare({propose, Value, Seq}, Data) when Seq > Data#state.seq_num ->
    io:format("Proposal with higher sequence number~n"),
    io:format("Value: ~p, Seq: ~p, seq_num: ~p", [Value, Seq, Data#state.seq_num]),
    {next_state, prepare, Data#state{seq_num = Seq, value = Value}};
prepare({propose, Value, Seq}, Data) when Seq =< Data#state.seq_num ->
    io:format("Proposal with less sequence number~n"),
    io:format("Value: ~p, Seq: ~p, seq_num: ~p", [Value, Seq, Data#state.seq_num]),
    {next_state, prepare, Data#state{seq_num = Seq}}.

handle_event({state, reset}, State, _Data) ->
    io:format("Reseting...~n"),
    {next_state, State, #state{}};
handle_event({mngm, current_state}, State, Data) ->
    print_state(State, Data),
    {next_state, State, Data}.

code_change(_OldVsn, StateName, Data, _Extra) ->
    {ok, StateName, Data}.

terminate(normal, _StateName, _Data) ->
    ok;
terminate(Reason, _StateName, _Data) ->
    io:format("Ubnormal termination ~p~n", [Reason]).

handle_info(_Info, State, Data) ->
    io:format("Unknown request~n"),
    {next_state, State, Data}.

%% Private Functions
print_state(State, #state{seq_num = N, value = V}) ->
    io:format("Current state: ~p, seq_num: ~p, value: ~p~n", [State, N, V]).
