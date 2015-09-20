-module(acceptor).

-behaviour(gen_server).

-include_lib("PaxEs/include/paxos_def.hrl").

%% Public API
-export([start/0, start_link/0]).

%% Client API
-export([print_state/0]).

%% Server API
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(acc_state, {accepted_value :: string(),
		   learners :: [node()],
		   last_promise :: integer(),
		   leader :: node()}).

-type acc_state() :: #acc_state{}.

%% Public API
start() ->
    gen_server:start({local, ?ACC_NAME}, ?MODULE, [], []).

start_link() ->
    gen_server:start_link({local, ?ACC_NAME}, ?MODULE, [], []).

%% Client API
print_state() ->
    gen_server:cast(?ACC_NAME, {mngm, print_state}).

%% callback functions
init(_Args) ->
    {{leader, Leader}, {acceptors, _}, {learners, Learners}} = utils:read_config(),
    InitState = #acc_state{accepted_value = "",
			  learners = Learners,
			  last_promise = -1,
			   leader = Leader},
    {ok, InitState}.

terminate(normal, _State) ->
    ok;
terminate(Reason, _State) ->
    io:format("Acceptor ubnormal termination ~p~n", [Reason]).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

handle_info(Info, State) ->
    io:format("Acceptor -> Hhhmm, unknown request ~p~n", [Info]),
    {noreply, State}.

handle_call(_Request, _From, State) ->
    io:format("No synchronous calls implemented yet~n"),
    {noreply, State}.

%% Value is here just for debugging
handle_cast({acceptor, prepare, From, Value, Seq}, State)
  when Seq > State#acc_state.last_promise ->
    io:format("ACCEPTOR received proposal with higher sequence number, promise!~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n",
	      [Value, Seq, State#acc_state.last_promise]),

    gen_server:cast({?PROP_NAME, From}, {proposer, accept_request,
					State#acc_state.last_promise,
					State#acc_state.accepted_value}),
    {noreply, State#acc_state{last_promise = Seq}};

%% I should send NACK here
handle_cast({acceptor, prepare, From, Value, Seq}, State) ->
    io:format("ACCEPTOR received proposal with lesser seq number, ignore!~n"),
    io:format("Value: ~p, Seq: ~p, last_promise: ~p~n",
	      [Value, Seq, State#acc_state.last_promise]),
    gen_server:cast({?PROP_NAME, From}, {proposer, accept_request, nack, Seq}),
    {noreply, State};

handle_cast({acceptor, accept, _From, Value, Seq}, State)
  when Seq >= State#acc_state.last_promise ->
    io:format("Accepted value ~p~n", [Value]),
    %% I should send a message to learners about the outcome
    %% and acknowledge to Proposer
    utils:bcast(learner_bcast(?LRN_NAME, Value), State#acc_state.learners),
    {noreply, State#acc_state{accepted_value = Value}};

handle_cast({mngm, stop}, State) ->
    {stop, normal, State};
handle_cast({mngm, reset}, State) ->
    NewState = #acc_state{accepted_value = "",
			  learners = State#acc_state.learners,
			  last_promise = -1,
			  leader = State#acc_state.leader},
    {noreply, NewState};
handle_cast({mngm, new_round}, State) ->
    {noreply, State#acc_state{accepted_value = ""}};
handle_cast({mngm, print_state}, State) ->
    io:format("State: ~p~n", [State]),
    {noreply, State};
handle_cast(_Request, State) ->
    io:format("Not implemented yet~n"),
    {noreply, State}.

%% Private functions
learner_bcast(ProcName, Value) ->
    fun(A) ->
	    gen_server:cast({ProcName, A}, {learner, learn, Value})
    end.
