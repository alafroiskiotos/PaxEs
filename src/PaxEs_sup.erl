%% Copyright (C) 2015
%% Antonios Kouzoupis <kouzoupis.ant@gmail.com>
%%
%% This file is part of PaxEs.
%%
%% PaxEs is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%%
%% PaxEs is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with PaxEs. If not, see <http://www.gnu.org/licenses/>.

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
	       transient,
	       2000,
	       worker,
	       [acceptor, utils]},
    Learner = {learner, {learner, start_link, []},
	      transient,
	      2000,
	      worker,
	      [learner]},
    Proposer = {proposer, {proposer, start_link, []},
		transient,
		2000,
		worker,
		[proposer, utils]},
    {ok, { {one_for_one, 5, 1}, [Proposer, Acceptor, Learner]} }.
%%====================================================================
%% Internal functions
%%====================================================================
