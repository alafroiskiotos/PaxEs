PaxEs
=====

Yet another Erlang implementation of Paxos algorithm.

Still it's in a very early stage -- I don't have a lot of free time

Build
-----

    $ rebar3 compile

TODO
----
* Decouple proposer-acceptor-learner
* Separate different roles state
* Add definitions to separate file
* Link processes under supervision tree
* Put leader and peers in enviroment variables
* Continue with the rest of Paxos :P
