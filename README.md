## Unigame (Client)

`Unigame` is the client package for `unigame-server`  It consists of a mixture of model-level code and SwiftUI classes designed to be used with the
server.  It is not a complete app.  Rather, it is intended to be added as a package dependency to a real SwiftUI app that offers a multi-player game.  The
game must conform to the overall "unigame model" offered by this package plus the server.

It is currently a work in progress and is not yet expected to work.

### So, what is the "unigame model"?

What I'm aiming for is a methodology for building multi-player games which involve taking turns and making moves.  Games like checkers, chess, tic-tac-toe, dominoes, and most card games.  There is no intent to support live-action games.

`Unigame` itself offers
- two `Communicator` implementations, "nearby only" (which uses Multi-peer communication) and server-based, which uses the `unigame-server` (separate repo).
A communicator (whether using the server or not) takes care of assembling a sufficient number of players, and then sequencing their turns and detecting when players have left the game.  The actual contents of the game are opaque to the Communicators and to the server, allowing the server infrastructure to be reused for multiple games.  Communicators also offer a built in chat channel which may be vital when using the server (players at a distance).  Players who are near each other in a quiet location and using the "nearby only" communicator will probably ignore the chat channel but it is there to support those use cases where it is useful.
- At the UI level, the `unigame` client provides some SwiftUI views which take care of player assembly, chat, and sequencing through other views which have to be provided by individual game apps.  Those are the help view, the setup view, and the playing view.
- The client also provides a model object that takes care of things like whose turn it is and who is allowed to transmit game states.  The game states themselves (including how they are encoded as byte arrays) is up to the individual apps.

### History and Plans

The `unigame` package was split off from the `anyCards` app.  The latter is pure UIKit with a playing surface that always shows and various modal dialogs that are launched by conditionally visible buttons.  As it is now, `anyCards` is a monolithic app which only supports card games.  But, it happens to work fine with `unigame-server` and has its own version of the communicators, etc. 

In `unigame` the behavior is far less modal, with the shown view depending partly on the phase of the game and partly on some navigation links.  This new UI uses SwiftUI rather than UIKit.  

The plan (once `unigame` is fully working) is to re-do `anyCards` to be dependent on `unigame` and to no longer duplicate any of its functionality.  Much of the `anyCards` UI would be redone using SwiftUI.  However, the main playing view,
with its cards, boxes, hand area, etc. might be retained in its current UIKit implementation using `UIViewControllerRepresentable`.
