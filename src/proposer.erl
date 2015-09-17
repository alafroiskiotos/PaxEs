-module(proposer).

-behaviour(gen_fsm).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([prop/1, stop/0]).

%% FSM API
-export([init/1, handle_event/3, handle_sync_event/4, code_change/4, terminate/3, handle_info/3]).

%% FSM States
-export([propose/2, accept_request/2]).

-record(prop_state, {seq_num,
		    proposed_value,
		    peers,
		    promises_received,
		    promised_values}).
%% Public API
start() ->
    gen_fsm:start({local, ?PROP_NAME}, ?MODULE, [], []).

start_link() ->
    gen_fsm:start_link({local, ?PROP_NAME}, ?MODULE, [], []).

%% Client API
prop(Value) ->
    gen_fsm:send_event(?PROP_NAME, {proposer, prepare, Value}).

stop() ->
    gen_fsm:send_all_state_event(?PROP_NAME, {mngm, stop}).

%% FSM API
init(_Args) ->
    %% I am the leader, I should do something
    {{leader, _}, {peers, Peers}} = utils:read_config(),
    InitState = #prop_state{seq_num = utils:pid_to_num(pid_to_list(self())),
		       proposed_value = '',
		       peers = Peers,
		       promises_received = 0,
		       promised_values = []},
    {ok, propose, InitState}.

%% Not implemented yet
handle_event({mngm, stop}, _State, Data) ->
    {stop, normal, Data};
handle_event(_Msg, State, Data) ->
    {next_state, State, Data}.

handle_sync_event(_Msg, _From, State, Data) ->
    {reply, Data, State, Data}.

code_change(_OldVsn, State, Data, _Extra) ->
    {ok, State, Data}.

terminate(normal, _State, _Data) ->
    io:format("Finished...~n"),
    ok;
terminate(Reason, _State, _Data) ->
    io:format("Ubnormal termination -> ~p~n", [Reason]).

handle_info(Info, State, Data) ->
    io:format("What do ya mean by ~p ?!?~n", [Info]),
    {next_state, State, Data}.


%% States

propose({proposer, prepare, Value}, Data) ->
    NextSeq = Data#prop_state.seq_num + 1,
    io:format("PROPOSER Proposing value ~p with seq num ~p~n", [Value, NextSeq]),
    %% Broadcast to acceptors
    utils:bcast(proposal_bcast(?ACC_NAME, Value, NextSeq), Data#prop_state.peers),
    {next_state, accept_request, Data#prop_state{seq_num = NextSeq, proposed_value = Value}}.

accept_request({proposer, accept_request, Seq, Value}, Data)
  when Data#prop_state.promises_received < length(Data#prop_state.peers) / 2 ->
    io:format("PROPOSER have not received quorum yet!~n"),
    {next_state, accept_request, update_promises_state(Seq, Value, Data)};
accept_request({proposer, accept_request, Seq, Value}, Data) ->
    io:format("PROPOSER received promises from quorum, hooray!~n"),
    NewData = update_promises_state(Seq, Value, Data),
    %% Inform the acceptors
    case compute_decide_value(NewData#prop_state.promised_values) of
	{ok, decide} ->
	    io:format("PROPOSER YEAY I can decide whatever I want~n"),
	    utils:bcast(accept_bcast(?ACC_NAME, Data#prop_state.proposed_value),
			Data#prop_state.peers),
	    {next_state, propose, Data#prop_state{proposed_value = '',
						  promises_received = 0,
						  promised_values = []}};
	{ok, Seq, Value} ->
	    io:format("PROPOSER hhmm I should decide val ~p with seq ~p~n", [Value, Seq]),
	    utils:bcast(accept_bcast(?ACC_NAME, Value), Data#prop_state.peers),
	    {next_state, propose, Data#prop_state{proposed_value = '',
						  promises_received = 0,
						  promised_values = []}}
    end.

%% Private functions
accept_bcast(ProcName, Value) ->
    fun(A) ->
	    gen_fsm:send_event({ProcName, A}, {acceptor, accept, Value})
    end.

proposal_bcast(ProcName, Value, Seq) ->
    fun(A) ->
	    gen_fsm:send_event({ProcName, A}, {prepare, acceptor, Value, Seq})
    end.

update_promises_state(Seq, Value, Data) ->
    P = Data#prop_state.promises_received + 1,
    Pv = [{Seq, Value} | Data#prop_state.promised_values],
    Data#prop_state{promises_received = P, promised_values = Pv}.

compute_decide_value(PromisedValues) ->
    SortedPv = lists:keysort(1, PromisedValues),
    {Seq, Value} = lists:last(SortedPv),
    case Value == '' of
	true ->
	    {ok, decide};
	false ->
	    {ok, Seq, Value}
    end.
