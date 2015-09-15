-module(paxos).

-behaviour(gen_fsm).

%% Public API
-export([start/0, start/1, start_link/0]).

%% Client API
-export([prop/1, print_state/0, get_data/0, set_data/1]).

%% FSM API
-export([init/1, handle_event/3, handle_sync_event/4, code_change/4, terminate/3, handle_info/3]).

%% FSM States
-export([prepare/2, promise/2, accept_request/2]).

-record(state, {seq_num = 0,
	       accepted_value,
	       proposed_value,
	       peers,
	       last_promise,
	       promises_received,
	       promised_values,
	       leader}).

-define(NAME, paxos).
-define(CONFIG, 'config').

%% Public API
start(Args) ->
    gen_fsm:start({local, ?NAME}, ?MODULE, [Args], []).
start() ->
    gen_fsm:start({local, ?NAME}, ?MODULE, [], []).

start_link() ->
    gen_fsm:start_link({local, ?NAME}, ?MODULE, [], []).

%% Client API
prop(Value) ->
    gen_fsm:send_event(?NAME, {prepare, proposer, Value}).

print_state() ->
    gen_fsm:send_all_state_event(?NAME, {mngm, current_state}).

get_data() ->
    gen_fsm:sync_send_all_state_event(?NAME, {mngm, get_data}).

set_data(Data) ->
    gen_fsm:send_all_state_event(?NAME, {mngm, set_data, Data}).

%% FSM API
init(Args) ->
    {ok, Terms} = file:consult(?CONFIG),
    {leader, Leader} = lists:keyfind(leader, 1, Terms),
    {peers, Peers} = lists:keyfind(peers, 1, Terms),
    case lists:member(leader, Args) of
	true ->
	    %% I am the Leader
	    NewPeers = lists:delete(node(), Peers),
	    Init = #state{seq_num = utils:pid_to_num(pid_to_list(self())),
		  accepted_value = 'None',
		  proposed_value = 'None',
		  peers = NewPeers,
		  last_promise = -1,
		  promises_received = 0,
		  promised_values = [],
		  leader = Leader},
	    {ok, prepare, Init};
	false ->
	    %% I am slave
	    Init = #state{seq_num = utils:pid_to_num(pid_to_list(self())),
		  accepted_value = 'None',
		  proposed_value = 'None',
		  peers = Peers,
		  last_promise = -1,
		  promises_received = 0,
		  promised_values = [],
		  leader = Leader},
	    {ok, prepare, Init}
    end.

%% States
prepare({prepare, acceptor, Value, Seq}, Data) when Seq > Data#state.last_promise ->
    io:format("Proposal with higher sequence number PROMISE~n"),
    io:format("Value: ~p, Seq: ~p, seq_num: ~p", [Value, Seq, Data#state.seq_num]),
    %% Send promise to leader
    %% I should take care of the case when the acceptor has not accepted a value yet
    %% but I should do it another day...
    gen_fsm:send_event({?NAME, Data#state.leader}, {accept_request, proposer,
						    Data#state.last_promise,
						    Data#state.accepted_value}),
    {next_state, prepare, Data#state{proposed_value = Value, last_promise = Seq}};

%% I should return NACK
prepare({prepare, acceptor, Value, Seq}, Data) when Seq =< Data#state.last_promise ->
    io:format("Proposal with less sequence number~n"),
    io:format("Value: ~p, Seq: ~p, seq_num: ~p", [Value, Seq, Data#state.seq_num]),
    {next_state, prepare, Data};

prepare({prepare, proposer, Value}, Data) ->
    NextSeq = Data#state.seq_num + 1,
    io:format("Proposing value ~p with seq: ~p~n", [Value, NextSeq]),
    %% Broadcast to acceptors
    utils:bcast_proposal(Data#state.peers, ?NAME, Value, NextSeq),
    {next_state, accept_request, Data#state{seq_num = NextSeq, proposed_value = Value}}.

%% Do something with the values received
accept_request({accept_request, proposer, Seq, Value}, Data) 
  when Data#state.promises_received < length(Data#state.peers) / 2 ->
    P = Data#state.promises_received + 1,
    io:format("Have not received quorum yet~n"),
    Pv = [{Seq, Value} | Data#state.promised_values],
    {next_state, accept_request, Data#state{promises_received = P, promised_values = Pv}};

accept_request({accept_request, proposer, Seq, Value}, Data) ->
    P = Data#state.promises_received + 1,
    Pv = [{Seq, Value} | Data#state.promised_values],
    %% Do something else here :P
    %% Remember to reset the counter of the received promises
    %% And also clean the promised values
    io:format("Received promises from quorum, hooray!~n"),
    case compute_decide_value(Pv) of
	{ok, decide} ->
	    io:format("YEAY I can decide whatever I want~n");
	{ok, Seq, Value} ->
	    io:format("I should decide val ~p with seq: ~p~n", [Value, Seq])
    end,
    {next_state, promise, Data#state{promises_received = P}}.
    
promise({something}, _Data) ->
    {stop, normal, null}.


%% Generic States
handle_event({state, reset}, State, _Data) ->
    io:format("Reseting...~n"),
    {next_state, State, #state{}};
handle_event({mngm, current_state}, State, Data) ->
    print_state(State, Data),
    {next_state, State, Data};
handle_event({mngm, set_data, NewData}, State, _Data) ->
    {next_state, State, NewData}.


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
    io:format("Data ~p~n", [Data]).

compute_decide_value(PromisedValues) ->
    SortedPv = lists:keysort(1, PromisedValues),
    io:format("Sorted:~p~n", [SortedPv]),
    {Seq, Value} = lists:last(SortedPv),
    case Value == 'None' of
	true ->
	    {ok, decide};
	false ->
	    {ok, Seq, Value}
    end.

