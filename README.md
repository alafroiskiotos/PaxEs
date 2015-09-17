PaxEs
=====

Yet another Erlang implementation of Paxos algorithm.

Still it's in a very early stage -- I don't have a lot of free time

Build
-----

    $ rebar3 compile

TODO
----
* Implement Learners
* Reset Proposer and go to next round
* Put leader and peers in enviroment variables (?)
* Add some documentation
* Continue with the rest of Paxos :P
* Implement failure detector (mmhh)
* Implement leader election (mmhh)
