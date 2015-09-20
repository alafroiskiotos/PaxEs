PaxEs
=====

Yet another Erlang implementation of Paxos algorithm.

Still it's in a very early stage -- I don't have a lot of free time

Build
-----

    $ rebar3 compile

TODO
----
* Persist acceptor critical state to file
* Write test case with multiple proposers
* Add some documentation
* Implement failure detector (mmhh)
* Implement leader election (mmhh)

Notes
-----
* For the moment 'leader' in acceptor state should be ignored.
* For the moment I assume that each node act as proposer && learner