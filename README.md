PaxEs
=====

Yet another Erlang implementation of Paxos algorithm.

Still it's in a very early stage -- I don't have a lot of free time

Build
-----

    $ rebar3 compile

TODO
----
* Implement learners
* Distinguish between proposer/acceptors/learners in configuration file
* Implement client API (propose/1, get/0 or something like this)
* Reset Proposer and go to next round
* Persist acceptor critical state to file
* Add some documentation
* Implement failure detector (mmhh)
* Implement leader election (mmhh)
