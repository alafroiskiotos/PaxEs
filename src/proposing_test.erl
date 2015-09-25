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

-module(proposing_test).

-export([start/1]).

-spec start([atom()]) -> ok.

start(Proplist) ->
    propose(Proplist, 0).

-spec propose([atom()], integer()) -> ok.

propose([X | Xs], V) ->
    send(X, {remote, propose, V}),
    propose(Xs, V + 1);
propose([], _) ->
    ok.

%% private functions

-spec send(atom(), term()) -> term().

send(Destination, Msg) ->
    {remoteapi, Destination} ! Msg.
