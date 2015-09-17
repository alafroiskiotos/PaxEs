-module(acceptor).

-behaviour(gen_fsm).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([print_state/0, get_data/0, set_data/1, stop/0]).

%% FSM API
-export([init/1, handle_event/3, handle_sync_event/4, code_change/4, terminate/3, handle_info/3]).

%% FSM States
-export([prepare/2, accept_request/2]).

-record(acc_state, {accepted_value,
		   peers,
		   last_promise,
		   leader}).

%% Public API
start() ->
    gen_fsm:start({local, ?ACC_NAME}, ?MODULE, [], []).

start_link() ->
    gen_fsm:start_link({local, ?ACC_NAME}, ?MODULE, [], []).

%% Client API

print_state() ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, current_state}).

get_data() ->
    gen_fsm:sync_send_all_state_event(?ACC_NAME, {mngm, get_data}).

set_data(Data) ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, set_data, Data}).

stop() ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, stop}).

%% FSM API
init(_Args) ->
    {{leader, Leader}, {peers, Peers}} = utils:read_config(),
    InitState = #acc_state{accepted_value = '',
			   peers = Peers,
			   last_promise = -1,
			   leader = Leader},
    {ok, prepare, InitState}.

%% States
prepare({prepare, acceptor, Value, Seq}, Data) when Seq > Data#acc_state.last_promise ->
    io:format("Proposal with higher sequence number PROMISE~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n", [Value, Seq, Data#acc_state.last_promise]),
    %% Send promise to leader
    %% I should take care of the case when the acceptor has not accepted a value yet
    %% but I should do it another day...
    gen_fsm:send_event({?PROP_NAME, Data#acc_state.leader}, {proposer, accept_request,
						    Data#acc_state.last_promise,
						    Data#acc_state.accepted_value}),
    {next_state, accept_request, Data#acc_state{last_promise = Seq}};

%% I should return NACK
prepare({prepare, acceptor, Value, Seq}, Data) when Seq =< Data#acc_state.last_promise ->
    io:format("Proposal with less sequence number~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n", [Value, Seq, Data#acc_state.last_promise]),
    {next_state, prepare, Data}.

accept_request({acceptor, accept, Value}, Data) ->
    io:format("Accepted value ~p~n", [Value]),
    NewData = Data#acc_state{accepted_value = Value},
    %% TODO: I should send a message to learners about the outcome
    {next_state, prepare, NewData}.

%% Generic States
handle_event({state, reset}, State, _Data) ->
    io:format("Reseting...~n"),
    {next_state, State, #acc_state{}};
handle_event({mngm, current_state}, State, Data) ->
    print_state(State, Data),
    {next_state, State, Data};
handle_event({mngm, set_data, NewData}, State, _Data) ->
    {next_state, State, NewData};
handle_event({mngm, stop}, _State, Data) ->
    {stop, normal, Data}.

handle_sync_event({mngm, get_data}, _From, State, Data) ->
    {reply, Data, State, Data}.

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
print_state(State, Data) ->
    io:format("State: ~p, Data: ~p~n", [State, Data]).
