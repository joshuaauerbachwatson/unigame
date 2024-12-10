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
import Observation   // Needed to support macro inspection in XCode

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

@Observable @MainActor @preconcurrency
public final class UnigameModel {
    // The handle to the specific game, providing details which the core model does not.
    public let gameHandle: any GameHandle
    
    // The defaults object (usually UserDefaults.standard but can be mocked for testing)
    private let defaults: UserDefaults

    // Access to UserDefaults settings.
    // We can't (and don't) use @AppStorage here because @Observable doesn't accommodate property wrappers.
    // We use stored properties with didSet (not computed properties) because we want direct observation of value changes.
    var userName: String {
        didSet {
            defaults.set(userName, forKey: UserNameKey)
        }
    }

    public var leadPlayer: Bool {
        didSet {
            defaults.set(leadPlayer, forKey: LeadPlayerKey)
        }
    }
    
    var numPlayers: Int {
        didSet {
            defaults.set(numPlayers, forKey: NumPlayersKey)
        }
    }
    
    var nearbyOnly: Bool {
        didSet {
            defaults.set(nearbyOnly, forKey: NearbyOnlyKey)
        }
    }
    
    var gameToken: String? {
        didSet {
            defaults.set(gameToken, forKey: GameTokenKey)
        }
    }
    
    var savedTokens: [String] {
        didSet {
            defaults.set(savedTokens, forKey: SavedTokensKey)
        }
    }
    
    // The HelpHandle supplied by the app (used to initiate a HelpController when needed)
    public var helpHandle: HelpHandle = NoHelpProvided()
    
    // The HelpController
    var helpController: HelpController {
        let mergedHelp = getMergedHelp(helpHandle)
        return HelpController(html: mergedHelp, email: helpHandle.email, returnText: nil,
                              appName: helpHandle.appName, tipReset: helpHandle.tipResetter)
    }
    
    // The list of players.  Always starts with just 'this' player but expands during discovery until play starts.
    // The array is ordered by Player.order fields, ascending.
    var players = [Player]()

    // The index in the players array assigned to 'this' player (the user of the present device).  Initially zero.
    public var thisPlayer : Int = 0    // Index may change since the order of players is determined by their order fields.

    // The index of the player whose turn it is (moves are allowed iff thisPlayer and activePlayer are the same)
    var activePlayer : Int = 0  // The player listed first always goes first but play rotates thereafter

    // Says whether it's this player's turn to make moves
    public var thisPlayersTurn : Bool {
        return thisPlayer == activePlayer
    }
    
    var solitaireMode: Bool {
        leadPlayer && numPlayers == 1
    }
    
    // The credentials to use with server based communicator (not used by multipeer communicator)
    // If not present, or not valid (expired), login is required.
    var credentials = CredentialStore.load()
    var mayConnect: Bool {
        return credentials?.valid ?? false
    }

    // The Communicator (nil until player search begins; remains non-nil through player search and during actual play)
    var communicator : Communicator? = nil

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player list is still being
    // constructed.  Game turns may not occur until play officially begins
    var playBegun = false

    // Indicates that the first yield by the leader has occurred.  Until this happens, the leader is allowed to change the
    // setup.  Afterwards, the setup is fixed.  This field is only meaningful in the leader's app instance.
    var setupIsComplete = false
    
    // Indicates that setup is in progress (the setup view should be shown and transmissions should be encoded with
    // 'duringSetup' true).
    var setupInProgress: Bool {
        leadPlayer && playBegun && !setupIsComplete && gameHandle.setupView != nil
    }
    
    // The transcript of the ongoing chat
    var chatTranscript: [String]? = nil
    
    // The Date/time of the last chat transcript update
    var lastChatMsgTime: Date? = nil
    
    // Indicates that chat is enabled
    var chatEnabled: Bool {
        communicator != nil && numPlayers > 1
    }

    // Send a chat msg to all peers
    func sendChatMsg(_ text: String) {
        let toSend = "[\(userName)] \(text)"
        communicator?.sendChatMsg(toSend)
    }

    // Indicates what views have been presented in the main navigation stack
    var presentedViews = [String]()
    
    // For error alert presentation
    var errorMessage: String? = nil
    var showingError: Bool = false
    var errorIsTerminal: Bool = false
    func resetError() {
        Logger.log("Resetting error")
        showingError = false
        errorMessage = nil
        if errorIsTerminal {
            Logger.log("Error was terminal")
            errorIsTerminal = false
            newGame()
        }
    }

    // Call this function to display a simple error.  No control over the dialog details other than the message.
    public func displayError(_ msg: String, terminal: Bool = false) {
        Logger.log("Displaying error, msg='\(msg)', terminal=\(terminal)")
        errorMessage = msg
        errorIsTerminal = terminal
        showingError = true
    }
    
    // Get the name of a player based on index
    public func getPlayer(index: Int) -> String {
        if index < players.count {
            return players[index].name
        }
        return "Player #\(index+1)"
    }
    
    // Reset to new game
    public func newGame(dueToError: Bool = false) {
        // Clean up old game
        if let communicator = self.communicator {
            Logger.log("Shutting down communicator \(dueToError ? "due to error" : "as requested")")
            communicator.shutdown(dueToError)
        }
        gameHandle.reset()
        // Set up new game
        players = [Player(userName, leadPlayer)]
        thisPlayer = 0
        activePlayer = 0
        communicator = nil
        playBegun = false
        setupIsComplete = false
        chatTranscript = nil // TODO what is the real desired lifecycle of the chat transcript?
        ensureNumPlayers()
        Logger.log("New game initialized")
    }
    
    // Main initializer.  The GameModel is supplied and things start out in the "new game" state
    // It is also possible to override the UserDefaults object.
    public init(gameHandle: GameHandle, defaults: UserDefaults = UserDefaults.standard){
        Logger.log("Instantiating a new UnigameModel")
        self.gameHandle = gameHandle
        self.defaults = defaults
        // fakeNames is staticly non-empty, hence force unwrap of randomElement() is safe
        let userName = defaults.string(forKey: UserNameKey) ?? fakeNames.randomElement()!
        self.userName = userName // in case just generated
        defaults.set(userName, forKey: UserNameKey)
        self.leadPlayer = defaults.bool(forKey: LeadPlayerKey)
        self.numPlayers  = defaults.integer(forKey: NumPlayersKey)
        self.nearbyOnly = defaults.bool(forKey: NearbyOnlyKey)
        self.gameToken = defaults.string(forKey: GameTokenKey)
        self.savedTokens = defaults.stringArray(forKey: SavedTokensKey) ?? []
        newGame()
    }
    
    // Dummy initializers for previews etc.
    convenience init() {
        self.init(gameHandle: DummyGameHandle())
    }
    
    convenience init(defaults: UserDefaults) {
        self.init(gameHandle: DummyGameHandle(), defaults: defaults)
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
    
    // Perform login function,
    func login() async {
        Logger.log("Logging in")
        let result = await tokenProvider.login()
        switch result {
        case let .success(creds):
            Logger.log("Login was successful")
            if !CredentialStore.store(creds) {
                Logger.log("Failed to store apparently valid credentials when performing login")
            }
            credentials = creds
        case let.failure(error):
            Logger.log("Login failed: \(error)")
            displayError(error.localizedDescription)
        }
    }

    // Starts the communicator and begins the search for players
    func connect() async {
        guard let player = players.first else {
            Logger.logFatalError("Communicator was asked to connect but the current player is not set")
        }
        guard let gameToken = gameToken, gameToken != "" else {
            Logger.logFatalError("Communicator was asked to connect but gameToken was not initialized")
        }
        Logger.log("Making communicator with nearbyOnly=\(nearbyOnly)")
        let communicator = await makeCommunicator(nearbyOnly: nearbyOnly, player: player, numPlayers: numPlayers,
                                                  game: gameToken, appId: gameHandle.appId, 
                                                  accessToken: credentials?.accessToken)
        self.communicator = communicator
        Logger.log("Got back valid communicator")
        for await event in communicator.events {
            switch event {
            case .newPlayerList(let numPlayers, let players):
                newPlayerList(numPlayers, players)
            case .gameChanged(let gameState):
                gameChanged(gameState)
            case .error(let error, let terminal):
                self.error(error, terminal)
            case .lostPlayer(let player):
                lostPlayer(player)
            case .newChatMsg(let msg):
                newChatMsg(msg)
            }
        }
    }
    
    // Indicate "turn over" for this player (yielding) with final state data
    public func yield() {
        let newActivePlayer = (thisPlayer + 1) % players.count
        transmit(newActivePlayer)
        activePlayer = newActivePlayer
    }

    // Transmit subroutine
    public func transmit(_ newActivePlayer: Int? = nil) {
        guard let communicator = self.communicator, thisPlayersTurn else {
            return // Make it possible to call this without worrying.
        }
        let activePlayer = newActivePlayer ?? self.activePlayer
        let gameInfo = [UInt8](gameHandle.encodeState(duringSetup: setupInProgress))
        let gameState =
            GameState(sendingPlayer: thisPlayer, activePlayer: activePlayer, gameInfo: gameInfo)
        communicator.send(gameState)
    }
}

// Compute the merged help using material provided by the HelpHandle and standard (templatized) Unigame Help
fileprivate func getMergedHelp(_ handle: HelpHandle) -> String {
    // Load the unigame help (templatized)
    guard let url = Bundle.module.url(forResource: "unigameHelp", withExtension: "html") else {
        Logger.logFatalError("Unigame help not present in the bundle")
        // This should not occur (packaging error)
    }
    // Read the contents
    guard var help = try? String(contentsOf: url, encoding: .utf8) else {
        Logger.logFatalError("Unigame help could not be read")
        // This should not occur (packaging error)
    }
    // Apply substitutions to the help
    help = help.replacingOccurrences(of: "%appName%", with: handle.appName)
    help = help.replacingOccurrences(of: "%generalDescription%", with: handle.generalDescription)
    help = help.replacingOccurrences(of: "%appSpecificTOC%", with: handle.appSpecificTOC)
    help = help.replacingOccurrences(of: "%appSpecificHELP%", with: handle.appSpecificHelp)
    let tipResetString = handle.tipResetter == nil ? "" :
            "<li><a href=\"javascript:window.webkit.messageHandlers.resetTips.postMessage('reset')\">Restore all tips</a>"
    help = help.replacingOccurrences(of: "%resetAllTips%", with: tipResetString)
    return help
}

// The CommunicatorDelegate portion of the logic
fileprivate let LostPlayerTemplate = "Lost contact with '%@'"
extension UnigameModel: @preconcurrency CommunicatorDispatcher {
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
                    Logger.log("numPlayers == players.count = \(players.count)")
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
        Logger.log("Received a new game state")
        if gameState.sendingPlayer == thisPlayer {
            // Don't accept remote game state updates that you originated yourself.
            Logger.log("Rejected incoming game state that originated with this player")
            return
        }
        if !playBegun {
            Logger.log("Play has not begun so not processing game state")
            return
        }
        if let err = gameHandle.stateChanged(gameState.gameInfo) {
            displayError(err.localizedDescription, terminal: false)
            return
        }
        activePlayer = gameState.activePlayer
    }
    
    // Handle an error detected by the communicator
    func error(_ error: any Error, _ deleteGame: Bool) {
        Logger.log("Received an error from the communicator")
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
        Logger.log("New chat message received")
        if chatTranscript == nil {
            chatTranscript = [msg]
        } else {
            chatTranscript!.append(msg)
        }
        lastChatMsgTime = Date.now
    }
}
