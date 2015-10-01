PaxEs
=====

Yet another Erlang implementation of [Paxos] [paxos] algorithm.

[paxos]: http://research.microsoft.com/en-us/um/people/lamport/pubs/paxos-simple.pdf "Paxos made simple"

License
=======

PaxEs is published under GPLv3.


Build
=====

    $ rebar3 compile

Execute
=======

Before executing PaxEs you should update the configuration file under ``src/`` directory.
Add the identifiers of the nodes in their respective role. One node can act as learner, acceptor and proposer at the same time.

Start the Erlang shell, append the binaries directory to the code path, set the node identifier with the **-name** or 
**-sname** flags and also set the secret cookie. For example:
``erl -pa _build/default/lib/PaxEs/ebin/ -sname ena -setcookie koko``

After that start the PaxEs application with ``application:start('PaxEs').`` in each node.
You should also start the client API with ``client_api:start().`` Finally, you can issue a write command with ``client_api:write(some_value).`` and read an already agreed value with ``client_api:read().``

Terminate the client API with ``client_api:stop().`` and the PaxEs application with ``application:stop('PaxEs').``

TODO
----
* Add some documentation
* Implement failure detector (mmhh)
* Implement leader election (mmhh)

Notes
-----
* For the moment 'leader' in acceptor state should be ignored.
