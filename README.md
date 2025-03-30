## Unigame

`Unigame` is an ongoing project to support an expanding suite of multiplayer iOS games, each player using their own device.  It started when I noticed that the older [anyCards](https://github.com/joshuaauerbachwatson/anyCards) project (a multiplayer card game with no built in rules) had a portion that could easily be broken out into a framework.   The purpose of the framework was to make it easy to create new multiplayer iOS games (not necessarily card games).

It is currently a work in progress and no betas or releases have been issued.  But, all the development is occuring in open source.

This repo contains the client-side support for the core unigame model.

### So, what is the "unigame model"?

The unigame model supports multi-player, multiple device, iOS games which involve taking turns and making moves.  Games like checkers, chess, tic-tac-toe, dominoes, most board games, and most card games.  There is no intent to support live-action games and certainly no intention to enter the "massive multi-player" space.  Games can support from one to modest number of players (no definite maximum but the UI is optimized for two to six players and will become overcrowded beyond that).

The code in this repo constitutes a `unigame` client library that can be incorporated using the Swift package manager.  It offers
- two `Communicator` implementations, "nearby only" (which uses Multi-peer communication) and server-based, which uses the [unigame-server](https://github.com/joshuaauerbachwatson/unigame-server) to support widely distributed particpation.
A communicator (whether using the server or not) takes care of assembling a sufficient number of players, and detecting when players have left the game.  The actual contents of the game are opaque to the Communicators and to the server, allowing the server infrastructure to be reused for multiple games.  Communicators also offer a built in chat channel which may be vital when using the server (players at a distance).  Players who are near each other in a quiet location and using the "nearby only" communicator will probably ignore the chat channel but it is there to support those use cases where it is useful.
- At the UI level, the `unigame` client provides some SwiftUI views which take care of player assembly, chat, and sequencing through other views which have to be provided by individual game apps.  Those are the help view, the setup view, and the playing view.
- The client also provides a model object that takes care of things like whose turn it is and who is allowed to transmit game states.  The game states themselves (including how they are encoded as byte arrays) is up to the individual apps.

### Plans

Currently, the only substantial game that uses `unigame` is `anyCards`, which has been reworked to use the framework.  But, I have not found `anyCards` to be convenient to use (it is too open-ended).  So, I plan to rework `anyCards` so that it, itself, becomes a framework for building card game UIs.  Then there could be many specific card games that depend on `unigame` directly and use `anyCards` to aid in building the UI.  Each game would have its own model, containing the rules of the game.

At present, there is also a [tictactoe](https://github.com/joshuaauerbachwatson/tictactoe) game which uses `unigame`.  This is a demo, a proof of concept.  I doubt very many people are that interested in playing tictactoe.  I also plan to develop more games (card games and non-card games) using `unigame` (and encourage others to do so).
