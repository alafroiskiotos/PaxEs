%%%-------------------------------------------------------------------
%% @doc PaxEs top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module('PaxEs_sup').

-behaviour(supervisor).

-include_lib("PaxEs/include/paxos_def.hrl").

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init(_Args) ->
    Acceptor = {acceptor, {acceptor, start_link, []},
	       temporary,
	       2000,
	       worker,
	       [acceptor, utils]},
    {{leader, Leader}, {_, _}} = utils:read_config(),
    io:format(Leader),
    case Leader == node() of
	true ->
	    Proposer = {proposer, {proposer, start_link, []},
			temporary,
			2000,
			worker,
			[proposer, utils]},
	    {ok, { {one_for_one, 5, 1}, [Proposer, Acceptor]} };
	false ->
	    {ok, { {one_for_one, 5, 1}, [Acceptor]} }
    end.
%%====================================================================
%% Internal functions
%%====================================================================
