/**
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import UIKit
import AuerbachLook

// The main phases of a game.
enum UnigamePhase {
    case Players, Setup, Playing
}

// Random names for users who never set their own identity
fileprivate let fakeNames = [ "Evelyn Soto", "Barrett Velasquez", "Esme Bonilla", "Aden Nichols", "Aliyah Dennis",
                              "Emanuel Vargas", "Andrea Caldwell", "Rylan Hines", "Poppy Barber", "Solomon Terrell",
                              "Paityn Thomas", "Logan Lester", "Averi Klein", "Marco Bender", "Lilyana Kline",
                              "Ramon Erickson", "Sabrina Shannon", "Eliel O’Neal", "Treasure Bass", "Landen Zamora",
                              "Sierra Roberson", "Shepherd Parsons", "Maia Correa", "Zakai Morse", "Kairi Gibbs",
                              "Deacon Cummings", "Nylah Murphy", "Cameron Graves", "Elle Poole", "Quincy Hall", "Leah Clay",
                              "Yosef Peterson", "Caroline Blake", "Zyaire Kennedy", "Brianna Avery", "Jakari Wallace",
                              "Arianna Kerr", "Louie Alexander", "Lyla Wheeler", "Kenneth Ball", "Abby Powell",
                              "Bennett Cummings", "Nylah Manning", "Seth Burns", "Emerson Schmitt", "Murphy Pena",
                              "Rachel Adams", "Hudson O’Connor", "Charli Diaz", "Nathan Mack", "Nadia Conner" ]

@Observable
public final class UnigameModel {
    // The handle to the specific game, providing details which the core model does not.
    let gameHandle: any GameHandle

   // Access to UserDefaults settings.
    // We can't (and don't) use @AppStorage here because @Observable doesn't accommodate property wrappers.
    var userName: String = {
        if let ans = UserDefaults.standard.string(forKey: UserNameKey), ans != "" {
            return ans
        }
        // Need to set UserDefaults manually in initializer since didSet will not be called.
        let ans = fakeNames.randomElement()! // fakeNames is staticly non-empty, hence the force unwrap is safe
        UserDefaults.standard.set(ans, forKey: UserNameKey)
        return ans
    }() {
        didSet {
            UserDefaults.standard.set(userName, forKey: UserNameKey)
        }
    }

    var leadPlayer: Bool = UserDefaults.standard.bool(forKey: LeadPlayerKey) {
        didSet {
            UserDefaults.standard.set(leadPlayer, forKey: LeadPlayerKey)
        }
    }
    
    var numPlayers: Int = UserDefaults.standard.integer(forKey: NumPlayersKey) {
        didSet {
            UserDefaults.standard.set(numPlayers, forKey: NumPlayersKey)
        }
    }
    
    var nearbyOnly: Bool = UserDefaults.standard.bool(forKey: NearbyOnlyKey) {
        didSet {
            UserDefaults.standard.set(nearbyOnly, forKey: NearbyOnlyKey)
        }
    }
    
    var gameToken: String? = UserDefaults.standard.string(forKey: GameTokenKey) {
        didSet {
            UserDefaults.standard.set(gameToken, forKey: GameTokenKey)
        }
    }
    
    var savedTokens: [String] = UserDefaults.standard.stringArray(forKey: SavedTokensKey) ?? [] {
        didSet {
            UserDefaults.standard.set(savedTokens, forKey: SavedTokensKey)
        }
    }
    
    // The list of players.  Always starts with just 'this' player but expands during discovery until play starts.
    // The array is ordered by Player.order fields, ascending.
    var players = [Player]()

    // The index in the players array assigned to 'this' player (the user of the present device).  Initially zero.
    var thisPlayer : Int = 0    // Index may change since the order of players is determined by their order fields.

    // The index of the player whose turn it is (moves are allowed iff thisPlayer and activePlayer are the same)
    var activePlayer : Int = 0  // The player listed first always goes first but play rotates thereafter

    // Says whether it's this player's turn to make moves
    var thisPlayersTurn : Bool {
        return thisPlayer == activePlayer
    }

    // The Communicator (nil until player search begins; remains non-nil through player search and during actual play)
    var communicator : Communicator? = nil

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player list is still being
    // constructed.  Game turns may not occur until play officially begins
    var playBegun = false

    // Indicates that the first yield by the leader has occurred.  Until this happens, the leader is allowed to change the
    // setup.  Afterwards, the setup is fixed.  This field is only meaningful in the leader's app instance.
    var setupIsComplete = false
    
    // The transcript of the ongoing chat
    var chatTranscript: [String]? = nil
    
    // Indicates something new in chatTranscript
    var chatTranscriptChanged: Bool = false
    
    // Indicates that chat is enabled
    var chatEnabled: Bool {
        communicator != nil && numPlayers > 1
    }
    
    // Indicates what views have been presented in the main navigation stack
    var presentedViews = [String]()
    
    // The phase of the game
    var phase: UnigamePhase {
        if !playBegun {
            return .Players
        }
        if leadPlayer && !setupIsComplete {
            return .Setup
        }
        return .Playing
    }
    
    // For error alert presentation
    var errorMessage: String? = nil
    var showingError: Bool = false
    var errorIsTerminal: Bool = false
    func displayError(_ msg: String, terminal: Bool = false) {
        errorMessage = msg
        errorIsTerminal = terminal
        showingError = true
    }
    func resetError() {
        showingError = false
        errorMessage = nil
        if errorIsTerminal {
            errorIsTerminal = false
            newGame()
        }
    }
    
    // Reset to new game
    public func newGame() {
        players = [Player(userName, leadPlayer)]
        thisPlayer = 0
        activePlayer = 0
        communicator = nil
        playBegun = false
        setupIsComplete = false
        chatTranscript = nil // TODO what is the real desired lifecycle of the chat transcript?
        ensureNumPlayers()
    }
    
    // Yield to next player
    public func yield() {
        // TODO needs more work because this needs to be integrated with transmission of a new gameState with
        // gameInfo provided by the unigame-core's consumer (a specific game).
        newGame() // TEMP
    }
    
    // Main initializer.  The GameModel is supplied and things start out in the "new game" state
    public init(gameHandle: GameHandle){
        self.gameHandle = gameHandle
        newGame()
    }
    
    // Dummy initializer for previews etc.
    convenience init() {
        self.init(gameHandle: DummyGameHandle())
    }
    
    // Establish the right number of players for the current value of leadPlayer at start of game.  If leadPlayer is true,
    // then the number is whatever is in UserDefaults, unless that is zero, in which case it should be 1.
    // If leadPlayer is false, the number must be zero (unknown).
    func ensureNumPlayers() {
        if leadPlayer {
            if numPlayers == 0 {
                numPlayers = 1
            }
        } else {
            numPlayers = 0
        }
    }
    
    // Starts the communicator and begins the search for players
    func connect() {
        guard let player = players.first else {
            Logger.logFatalError("Communicator was asked to connect but the current player is not set")
        }
        guard let gameToken = gameToken, gameToken != "" else {
            Logger.logFatalError("Communicator was asked to connect but gameToken was not initialized")
        }
        Logger.log("Making communicator with nearbyOnly=\(nearbyOnly)")
        makeCommunicator(nearbyOnly: nearbyOnly, player: player, gameToken: gameToken,
                         delegate: self) { (communicator, error) in
            if let communicator = communicator {
                Logger.log("Got back valid communicator")
                self.communicator = communicator
            } else if let error = error {
                self.displayError("Could not establish communication: \(error.localizedDescription)", terminal: true)
            } else {
                Logger.logFatalError("makeCommunicator got unexpected response")
            }
        }
    }
    
    // Indiate "turn over" for this player (yielding) with final state data
    func yield(_ data: Data) {
        let newActivePlayer = (thisPlayer + 1) % players.count
        transmitState(data, newActivePlayer: newActivePlayer)
        activePlayer = newActivePlayer
    }
    
    // Transmit interim results during setup.  Used only by the setup view, which is only shown to the lead player
    func transmitSetup(_ data: Data) {
        transmit(activePlayer: activePlayer, setup: true, gameInfo: data)
    }
    
    // Transmit interim state with or without yielding.  Used only by the playing view
    // Yielding should be done via the yield function which, yes, calls this function.
    func transmitState(_ data: Data, newActivePlayer: Int? = nil) {
        let activePlayer = newActivePlayer ?? self.activePlayer
        transmit(activePlayer: activePlayer, setup: false, gameInfo: data)
    }

    // Transmit subroutine
    private func transmit(activePlayer: Int, setup: Bool, gameInfo: Data) {
        guard let communicator = self.communicator, thisPlayersTurn else {
            return // Make it possible to call this without worrying.
        }
        let gameState =
            GameState(sendingPlayer: thisPlayer, activePlayer: activePlayer, setup: setup, gameInfo: gameInfo)
        communicator.send(gameState)
    }
}

// The CommunicatorDelegate portion of the logic
fileprivate let LostPlayerTemplate = "Lost contact with '%@'"
extension UnigameModel: CommunicatorDelegate {
    var tokenProvider: any TokenProvider {
        return gameHandle.tokenProvider
    }
    
    // Respond to a new player list during game initiation.  We do not use this call later for lost players;
    // we use `lostPlayer` for that.  The received players array is already properly sorted.
    func newPlayerList(_ newNumPlayers: Int, _ newPlayers: [Player]) {
        Logger.log("newPlayerList received, newNumPlayers=\(newNumPlayers), \(newPlayers.count) players present")
        self.players = newPlayers
        if players.count > 0 { // Should always be true, probably, but give communicators some slack
            // Recalculate thisPlayer based on new list
            guard let thisPlayer = players.firstIndex(where: {$0.name == userName})
            else {
                Logger.log("The player for this app is not in the received player list")
                return
            }
            self.thisPlayer = thisPlayer
            
            // Manage incoming numPlayers.  Ignore it if leader.  For others, store it but 0 means unknown.
            if !leadPlayer {
                numPlayers = newNumPlayers
            }
            if numPlayers > 0 {
                // Check whether we now have the right number of players.  It is an error to have too many.
                // If we have exactly the right number, check that there is exactly one lead player and indicate an error
                // if there is none or more than one.  If that test is passed, indicate that play can begin.
                if numPlayers < players.count {
                    displayError("Too Many Players", terminal: true)
                    return
                } else if numPlayers == players.count {
                    for player in 0..<numPlayers {
                        if players[player].order == 1 {
                            if player > 0 {
                                displayError("Too Many Leaders", terminal: true)
                                return
                            }
                        } else if player == 0 {
                            displayError("No Lead Player", terminal: true)
                            return
                        }
                    }
                    // Player list is complete with exactly one lead player
                    playBegun = true
                    Logger.log("Player list complete, play begun")
                } // else player list not complete
            } // else we don't know the number of players yet
        } // else this call does not provide any players
    }

    // Handle a new game state
    func gameChanged(_ gameState: GameState) {
        if gameState.sendingPlayer == thisPlayer {
            // Don't accept remote game state updates that you originated yourself.
            Logger.log("Rejected incoming game state that originated with this player")
            return
        }
        if !playBegun {
            Logger.log("Play has not begun so not processing game state")
            return
        }
        if let err = gameHandle.stateChanged(gameState.gameInfo, setup: gameState.setup && !leadPlayer) {
            displayError(err.localizedDescription, terminal: false)
            return
        }
    }
    
    // Handle an error detected by the communicator
    func error(_ error: any Error, _ deleteGame: Bool) {
        displayError(error.localizedDescription, terminal: deleteGame)
    }

    // Handle lost player notification
    func lostPlayer(_ lost: Player) {
        Logger.log("Lost player \(lost.display)")
        let lostPlayerMessage = String(format: LostPlayerTemplate, lost.display)
        displayError(lostPlayerMessage, terminal: true)
    }
    
    // Handle incoming chat message
    func newChatMsg(_ msg: String) {
        if chatTranscript == nil {
            chatTranscript = [msg]
        } else {
            chatTranscript!.append(msg)
        }
        if presentedViews.last != "chat" {
            // If the chat view is not showing we use the following to fire an alert to also hold the message
            chatTranscriptChanged = true // Will be reset by alert after presentation
        }
    }
}
