%% Acceptor process name
-define(ACC_NAME, acceptor).

%% Proposer process name
-define(PROP_NAME, proposer).

%% Configuration file -- TO BE REMOVED
-define(CONFIG, 'src/config').

%% FSM State -- SHOULD BE REVISED
-record(state, {seq_num = 0,
	       accepted_value,
	       proposed_value,
	       peers,
	       last_promise,
	       promises_received,
	       promised_values,
	       leader}).
