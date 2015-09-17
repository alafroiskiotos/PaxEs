%%%-------------------------------------------------------------------
%% @doc PaxEs top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module('PaxEs_sup').

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link(Args) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [Args]).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init(Args) ->
    Acceptor = {acceptor, {acceptor, start_link, []},
	       temporary,
	       2000,
	       worker,
	       [acceptor, utils]},
    case lists:member(true, Args) of
	true ->
	    Proposer = {proposer, {proposer, start_link, Args},
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
