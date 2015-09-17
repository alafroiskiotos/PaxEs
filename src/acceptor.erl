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

-record(acc_state, {accepted_value :: string(),
		   peers :: [node()],
		   last_promise :: integer(),
		   leader :: node()}).

-type acc_state() :: #acc_state{}.

%% Public API
-spec start() -> {ok, pid()} | ignore | {error, term()}.

start() ->
    gen_fsm:start({local, ?ACC_NAME}, ?MODULE, [], []).

-spec start_link() -> {ok, pid()} | ignore | {error, term()}.

start_link() ->
    gen_fsm:start_link({local, ?ACC_NAME}, ?MODULE, [], []).

%% Client API

-spec print_state() -> ok.

print_state() ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, current_state}).

-spec get_data() -> #acc_state{}.

get_data() ->
    gen_fsm:sync_send_all_state_event(?ACC_NAME, {mngm, get_data}).

-spec set_data(#acc_state{}) -> ok.

set_data(Data) ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, set_data, Data}).

-spec stop() -> ok.

stop() ->
    gen_fsm:send_all_state_event(?ACC_NAME, {mngm, stop}).

%% FSM API

-spec init(term()) -> {ok, prepare, acc_state()}.

init(_Args) ->
    {{leader, Leader}, {peers, Peers}} = utils:read_config(),
    InitState = #acc_state{accepted_value = "",
			   peers = Peers,
			   last_promise = -1,
			   leader = Leader},
    {ok, prepare, InitState}.

%% States

-spec prepare({atom(), atom(), string(), integer()}, acc_state()) ->
		     {next_state, atom(), acc_state()}.

%% Value is here just for debugging. I should remove it later
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

-spec accept_request({atom(), atom(), string(), integer()}, acc_state()) ->
			    {next_state, atom(), acc_state()}.

accept_request({acceptor, accept, Value, Seq}, Data)
  when Seq >= Data#acc_state.last_promise ->
    io:format("Accepted value ~p~n", [Value]),
    NewData = Data#acc_state{accepted_value = Value},
    %% TODO: I should send a message to learners about the outcome
    %% and acknowledge to Proposer
    {next_state, prepare, NewData}.

%% Generic States

-spec handle_event({atom(), atom()}, atom(), acc_state()) ->
			  {next_state, atom(), acc_state()}
			  | {stop, normal, acc_state()}.

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

-type reply() :: acc_state().

-spec handle_sync_event({atom(), atom()}, {pid(), atom()}, atom(), acc_state()) ->
			       {reply, acc_state(), atom(), reply()}.

handle_sync_event({mngm, get_data}, _From, State, Data) ->
    {reply, Data, State, Data}.

-spec code_change(term() | {down, term()}, atom(), acc_state(), term()) ->
			 {ok, atom(), acc_state()}.

code_change(_OldVsn, StateName, Data, _Extra) ->
    {ok, StateName, Data}.

-spec terminate(atom(), atom(), acc_state()) ->
		       ok | atom() | term().

terminate(normal, _StateName, _Data) ->
    ok;
terminate(Reason, _StateName, _Data) ->
    io:format("Ubnormal termination ~p~n", [Reason]).

-spec handle_info(term(), term(), acc_state()) ->
			 {next_state, atom(), acc_state()}.

handle_info(_Info, State, Data) ->
    io:format("Unknown request~n"),
    {next_state, State, Data}.

%% Private Functions

-spec print_state(atom(), acc_state()) -> ok.

print_state(State, Data) ->
    io:format("State: ~p, Data: ~p~n", [State, Data]).
