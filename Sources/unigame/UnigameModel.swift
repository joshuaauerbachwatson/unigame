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

fileprivate let MustFind = "[Missing]"
fileprivate let Searching = "[Searching]"
fileprivate let ExpectingMore = "...expecting more..."

// Describes whether optional scoring is requested and, if so, whether players are restricted to
// changing only their own score.
public enum Scoring {
    case Off, Open, SelfOnly
}

@Observable @MainActor @preconcurrency
public final class UnigameModel<T> where T: GameHandle {
    // The handle to the specific game, providing details which the core model does not.
    public var gameHandle: T
    
    // The defaults object (usually UserDefaults.standard but can be mocked for testing)
    private let defaults: UserDefaults

    // Access to UserDefaults settings.
    // We can't (and don't) use @AppStorage here because @Observable doesn't accommodate property wrappers.
    // We use stored properties with didSet (not computed properties) because we want direct
    // observation of value changes.
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
    
    public var numPlayers: Int {
        didSet {
            defaults.set(numPlayers, forKey: NumPlayersKey)
        }
    }
    
    var nearbyOnly: Bool {
        didSet {
            defaults.set(nearbyOnly, forKey: NearbyOnlyKey)
        }
    }
    
    var groupToken: String? {
        didSet {
            defaults.set(groupToken, forKey: GroupTokenKey)
        }
    }
    
    var savedTokens: [String] {
        didSet {
            defaults.set(savedTokens, forKey: SavedTokensKey)
        }
    }
    
    // A convenience accessor for the HelpHandle supplied with the GameHandle
    public var helpHandle: HelpHandle {
        gameHandle.helpHandle
    }
    
    // The HelpController
    var helpController: HelpController {
        let mergedHelp = getMergedHelp(helpHandle)
        return HelpController(html: mergedHelp, baseURL: helpHandle.baseURL, email: helpHandle.email,
                              returnText: nil, appName: helpHandle.appName, tipReset: helpHandle.tipResetter)
    }

    // The token provider.  Although we provide the `TokenProvider` abstraction to hide some Auth0-specific
    // details, we actually hardcode the Auth0 provider here.  There are no immediate plans to cover
    // providers other than Auth0.
    let tokenProvider: TokenProvider? = hasNeededPlist ? Auth0TokenProvider() : nil

    // The list of players.  Always starts with just 'this' player but expands during discovery until
    // play starts.  The array is ordered by Player.order fields, ascending.
    var players = [Player]()
    
    // Variable indicating that the player list is being drained (at least one player has withdrawn and
    // others are expected to withdraw)
    var draining = false
    
    // The index in the players array assigned to 'this' player (the user of the present device).
    // Initially zero.
    public var thisPlayer : Int = 0 // Index may change; order of players determined by order fields.

    // The index of the player whose turn it is (moves are allowed iff thisPlayer and activePlayer are
    // the same).
    var activePlayer : Int = 0  // The player listed first always goes first but play rotates thereafter
    
    // Indicates the winner of the game (once a winner is determined, moves must stop but the
    // game is not considered "Ended").
    public var winner : Int? = nil
    
    // Indicates form of scoring requested, if any
    public var scoring: Scoring

    // Says whether it's this player's turn to make moves
    public var thisPlayersTurn : Bool {
        return thisPlayer == activePlayer && winner == nil
    }
    
    // Predicate for "solitaire mode"
    var solitaireMode: Bool {
        leadPlayer && numPlayers == 1
    }

    var credentials: Credentials? = nil

    // Indicates that valid credentials are present
    var hasValidCredentials: Bool {
        return credentials?.valid ?? false
    }
    
    // Indicates that a token provider is available
    var hasTokenProvider: Bool {
        tokenProvider != nil
    }
    
    // Indicates that an Auth0.plist is available
    static var hasNeededPlist: Bool {
        let path = Bundle.main.path(forResource: "Auth0", ofType: "plist")
        return path != nil
    }

    // The Communicator (nil until player search begins; remains non-nil through player search
    // and during actual play)
    var communicator : Communicator? = nil
    
    // Convenience predicate for whether we are communicating
    var communicating: Bool {
        communicator != nil
    }

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player
    // list is still being constructed.  Game turns may not occur until play officially begins.
    var playBegun = false

    // Indicates that the first yield by the leader has occurred.  Until this happens, the leader is
    // allowed to change the setup.  Afterwards, the setup is fixed.  This field is only meaningful
    // in the leader's app instance.
    var setupIsComplete = false
    
    // Indicates that setup is in progress (the setup view should be shown and transmissions should be
    // encoded with 'duringSetup' true).
    var setupInProgress: Bool {
        leadPlayer && playBegun && !setupIsComplete && gameHandle.setupView != nil
    }
    
    // The transcript of the ongoing chat
    var chatTranscript: [String]? = nil
    
    // The Date/time of the last chat transcript update
    var lastChatMsgTime: Date? = nil
    
    // Indicates that chat is enabled
    var chatEnabled: Bool {
        communicating && numPlayers > 1
    }

    // Determines whether the score of a particular player may be changed by the
    // current player.
    func mayChangeScore(_ player: Int) -> Bool {
        if scoring == .Off || !thisPlayersTurn {
            return false
        }
        return scoring == .Open || player == thisPlayer
    }
    
    // Change the score of a player.  Note: `mayChangeScore` must be checked so that this method
    // is not called when doing so would be illegal.
    func changeScore(of: Int, to: Int32) {
        if !mayChangeScore(of) {
            Logger.logFatalError("Changing a score when not permitted")
        }
        players[of].score = to
        transmit()
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
    var errorTitle: String = "Error"
    var showingError: Bool = false
    var errorIsTerminal: Bool = false
    func resetError() {
        Logger.log("Resetting error")
        showingError = false
        errorMessage = nil
        errorTitle = "Error"
        if errorIsTerminal {
            Logger.log("Error was terminal")
            errorIsTerminal = false
            newGame()
        }
    }

    // Call this function to display a simple error.  No control over the dialog details other than
    // the message.
    public func displayError(_ msg: String, terminal: Bool = false, title: String = "Error") {
        Logger.log("Displaying error, msg='\(msg)', terminal=\(terminal)")
        errorMessage = msg
        errorTitle = title
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
    
    // Withdraw from the game (starts graceful termination sequence)
    public func withdraw() {
        if playBegun {
            draining = true
            communicator?.send(GameState(withdrawing: thisPlayer))
        } else {
            newGame()
        }
    }
    
    // Initialize the credentials field if needed and credentials available
    func reconcileCredentials() {
        if !hasValidCredentials, let tokenProvider, tokenProvider.hasValid() {
            Task { @MainActor in
                switch await tokenProvider.credentials() {
                case .success(let creds):
                    credentials = creds
                case .failure(let err):
                    displayError(err.localizedDescription)
                }
            }
        }
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
        thisPlayer = 0
        activePlayer = 0
        winner = nil
        communicator = nil
        playBegun = false
        setupIsComplete = false
        chatTranscript = nil // TODO what is the real desired lifecycle of the chat transcript?
        ensureNumPlayers()
        players = [Player(userName, leadPlayer)]
        draining = false
        reconcileCredentials()
        if !hasTokenProvider {
            // Force nearby only when login is impossible
            nearbyOnly = true
        }
        Logger.log("New game initialized")
        Logger.log("userName=\(userName)")
        Logger.log("leadPlayer=\(leadPlayer)")
        Logger.log("numPlayers=\(numPlayers)")
        Logger.log("nearbyOnly=\(nearbyOnly)")
        Logger.log("groupToken=\(groupToken ?? "<missing>")")
        Logger.log("There are \(savedTokens.count) saved tokens")
    }
    
    // Main initializer.  A GameHandle class is supplied, to be instantiated dynamically.
    // Things start out in the "new game" state.  It is also possible to override the UserDefaults object.
    public init(gameHandle: T, defaults: UserDefaults = UserDefaults.standard) where T: GameHandle {
        Logger.log("Instantiating a new UnigameModel")
        self.gameHandle = gameHandle
        self.defaults = defaults
        self.scoring = gameHandle.initialScoring
        // fakeNames is staticly non-empty, hence force unwrap of randomElement() is safe
        let userName = defaults.string(forKey: UserNameKey) ?? fakeNames.randomElement()!
        self.userName = userName // in case just generated
        defaults.set(userName, forKey: UserNameKey)
        self.leadPlayer = defaults.bool(forKey: LeadPlayerKey)
        self.numPlayers  = defaults.integer(forKey: NumPlayersKey)
        self.nearbyOnly = defaults.bool(forKey: NearbyOnlyKey)
        self.groupToken = defaults.string(forKey: GroupTokenKey)
        self.savedTokens = defaults.stringArray(forKey: SavedTokensKey) ?? []
        self.gameHandle.model = self // GameHandle implementations expected to use 'weak'
        newGame()
    }
    
    // Establish the right number of players for the current value of leadPlayer at start of game.
    // If leadPlayer is true, then the number is whatever is in UserDefaults, unless that is zero,
    // in which case it should be 1.  If leadPlayer is false, the number must be zero (unknown).
    func ensureNumPlayers() {
        if leadPlayer {
            if numPlayers == 0 {
                numPlayers = 1
            }
        } else {
            numPlayers = 0
        }
    }
    
    // The number of player labels (based on players, numPlayers, and communicating)
    var numPlayerLabels: Int {
        if numPlayers == 0 && communicating {
            // Non-lead player expecting an unknown number of additional players
            return players.count + 1
        }
        // All other cases
        return max(numPlayers, players.count)
    }
    
    // Get the correct PlayerLabel view for a given player label index.
    // Assumes without checking that the index is in the range 0..<numPlayerLabels
    func getPlayerLabel(_ index: Int) -> PlayerLabel<T> {
        if index < players.count {
            return PlayerLabel(id: index, name: players[index].name)
        }
        if numPlayers == 0 && communicating {
            return PlayerLabel(id: index, name: ExpectingMore)
        }
        return PlayerLabel(id: index, name: communicating ? Searching : MustFind)
    }
    
    // Perform login function,
    func login() async {
        guard let tokenProvider else {
            Logger.logFatalError("login function executed when it should have been inaccessible")
        }
        let result = await tokenProvider.login()
        switch result {
        case let .success(creds):
            if let err = tokenProvider.store(creds) {
                displayError(err.localizedDescription)
                return
            }
            credentials = creds
        case let .failure(error):
            displayError(error.localizedDescription)
        }
    }
    
    // Perform Logout function
    func logout() async {
        guard let tokenProvider else { return }
        if let err = await tokenProvider.logout() {
            Logger.log("Logout failed: \(err)")
            displayError(err.localizedDescription)
            return
        }
        // Logout succeeded and credential store removed.  Nullify credentials in the model.
        credentials = nil
    }

    // Starts the communicator and begins the search for players
    func connect() async {
        if players.count < 1 {
            Logger.logFatalError("Communicator was asked to connect but the current player is not set")
        }
        players[0] = Player(userName, leadPlayer) // Ensure using latest player name
        guard let groupToken, groupToken != "" else {
            Logger.logFatalError("Communicator was asked to connect but groupToken was not initialized")
        }
        Logger.log("Making communicator with nearbyOnly=\(nearbyOnly)")
        let communicator = await makeCommunicator(nearbyOnly: nearbyOnly, player: players[0],
                                                  numPlayers: numPlayers, groupToken: groupToken,
                                                  gameId: gameHandle.gameId,
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
        var scores = [Int32]()
        if scoring != .Off {
            scores = players.map { $0.score }
        }
        let gameState =
            GameState(sendingPlayer: thisPlayer, activePlayer: activePlayer, gameInfo: gameInfo,
                      scores: scores)
        communicator.send(gameState)
    }
}

fileprivate let problemReportingTOC="<li><a href=\"#Problems\">Reporting Problems</a></li>"

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
    // Load the problem reporting section, if required (also templatized)
    var problemReporting = ""
    if handle.email != nil {
        guard let url = Bundle.module.url(forResource: "problemReporting", withExtension: "html") else {
            Logger.logFatalError("Unigame help problem reporting section not present in the bundle")
        }
        // Read the contents
        guard let reporting = try? String(contentsOf: url, encoding: .utf8) else {
            Logger.logFatalError("Unigame help problem reporting section could not be read")
        }
        problemReporting = reporting
    }
    // Insert problem reporting or empty space if not used
    help = help.replacingOccurrences(of: "%problemReporting%", with: problemReporting)
    // Apply substitutions to the help (including in the reporting section)
    help = help.replacingOccurrences(of: "%appName%", with: handle.appName)
    help = help.replacingOccurrences(of: "%generalDescription%", with: handle.generalDescription)
    help = help.replacingOccurrences(of: "%appSpecificTOC%", with: generateTOC(handle.appSpecificTOC))
    let reportingTOC = handle.email != nil ?  problemReportingTOC : ""
    help = help.replacingOccurrences(of: "%problemReportingTOC%", with: reportingTOC)
    help = help.replacingOccurrences(of: "%appSpecificHelp%", with: handle.appSpecificHelp)
    // Fill in special actions section
    if handle.email != nil || handle.tipResetter != nil {
        // Suppress entire section unless it has at least one action
        let sendFeedbackString = handle.email == nil ? "" :
        "<li><a href=\"javascript:window.webkit.messageHandlers.sendFeedback.postMessage('send')\">" +
        "Report a Problem or Send Feedback</a>"
        let tipResetString = handle.tipResetter == nil ? "" :
        "<li><a href=\"javascript:window.webkit.messageHandlers.resetTips.postMessage('reset')\">" +
        "Restore all tips</a>"
        let specialActions = """
    <h2>Special Actions</h2>
    <ul>
        \(sendFeedbackString)
        \(tipResetString)
    </ul>
"""
        help = help.replacingOccurrences(of: "%specialActions%", with: specialActions)
    }
    return help
}

// Build the app-specific TOC String from the provided tag/text pairs
fileprivate func generateTOC(_ pairs: [HelpTOCEntry]) -> String {
    var ans = ""
    var indented = false
    for pair in pairs {
        if pair.indented && !indented {
            ans += "        <ul>\n"
            indented = true
        } else if !pair.indented && indented {
            ans += "        </ul>\n"
            indented = false
        }
        let indent = indented ? "    " : ""
        ans += indent + "        <li><a href=\"#\(pair.tag)\">\(pair.text)</a></li>\n"
    }
    if indented {
        ans += "        </ul>\n"
    }
    return ans
}

// The CommunicatorDelegate portion of the logic
fileprivate let LostPlayerTemplate = "Lost contact with '%@'"
extension UnigameModel: @preconcurrency CommunicatorDispatcher {
    // Respond to a new player list during game initiation.  We do not use this call later for lost players;
    // we use `lostPlayer` for that.  The received players array is already properly sorted.
    func newPlayerList(_ newNumPlayers: Int, _ newPlayers: [Player]) {
        Logger.log(
            "newPlayerList received, newNumPlayers=\(newNumPlayers), \(newPlayers.count) players present")
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
                // If we have exactly the right number, check that there is exactly one lead player and
                // indicate an error if there is none or more than one.  If that test is passed, indicate
                // that play can begin.
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
        // Determine if this is a withdrawal and handle specially
        if gameState.activePlayer == WithdrawalIndicator {
            // If this is the first indication that the game is draining, send your own withdrawal
            // and notify the user that the game is ending and which player has withdrawn
            if !draining {
                communicator?.send(GameState(withdrawing: thisPlayer))
                displayError("Player \(players[gameState.sendingPlayer].name) is ending the game",
                             terminal: true, title: "Note")
            }
            draining = true
            // Mark the player as withdrawn
            players[gameState.sendingPlayer] = Player.withdrawn
            // If all players have withdrawn, start a new game from scratch
            if players.dropFirst().allSatisfy( { $0 == Player.withdrawn } ) {
                newGame()
            }
            return
        }
        // Otherwise, not a withdrawal so process as a move in the game
        if let err = gameHandle.stateChanged(gameState.gameInfo) {
            displayError(err.localizedDescription, terminal: false)
            return
        }
        activePlayer = gameState.activePlayer
        for i in 0..<gameState.scores.count {
            if i >= players.count {
                return
            }
            Logger.log("Setting player \(i) score to \(gameState.scores[i])")
            players[i].score = gameState.scores[i]
        }
    }
    
    // Handle an error detected by the communicator
    func error(_ error: any Error, _ deleteGame: Bool) {
        Logger.log("Received an error from the communicator")
        if !draining {
            displayError(error.localizedDescription, terminal: deleteGame)
        }
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
