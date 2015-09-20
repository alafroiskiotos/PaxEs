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
* When proposing add a timer, if time expires, make new proposal
  with higher sequence number
* Reset Proposer and go to next round
* Add some documentation
* Continue with the rest of Paxos :P
* Implement failure detector (mmhh)
* Implement leader election (mmhh)
