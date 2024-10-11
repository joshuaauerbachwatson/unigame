### The client "starter package" for working with `unigame-server`

The `unigame-core` is a mixture of model-level code and SwiftUI classes designed to be used with `unigame-server`.  It is not a complete SwiftUI app.  Rather,
it is intended to be added as a package dependency to a real SwiftUI app that plays a game matching the overall unigame model.

Currently a work in progress.

### So, what is the "unigame model"?

What I'm aiming for is a methodology for building multi-player games which are not live action games but rather games involving taking turns and making moves.  The
core (this repo) offers
- two `Communicator` implementations, "nearby only" (which uses Multi-peer communication) and server-based, which uses the `unigame-server` (separate repo).
A communicator (whether using the server or not) takes care of assembling a sufficient number of players, and then sequencing their turns and detecting when players have left the game.  The actual contents of the game are opaque to the Communicators and to the server, allowing the server infrastructure to be reused for multiple games.  Communicators also offer a built in chat channel which may be vital when using the server (players at a distance).  Players who are near each other in a quiet location and using the "nearby only" communicator will probably ignore the chat channel but it is there to support those use cases where it is useful.
- At the UI level, the core provides some SwiftUI views which take care of player assembly, chat, and sequencing through other views which have to be provided by individual game apps.  Those are the help view, the setup view, and the playing view.  It provides a model object that takes care of things like whose turn it is and who is allowed to transmit game states.  The game states themselves (including how they are encoded as byte arrays) is up to the individual apps.
