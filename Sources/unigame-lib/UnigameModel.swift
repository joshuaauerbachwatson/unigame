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

// Temp placeholder for TokenProvider.
// TODO We need to figure out how to thread everything through in the end.
struct DummyTokenProvider: TokenProvider {
    func login(_ handler: @escaping (Credentials?, (any LocalizedError)?) -> ()) {
        let ans = Credentials(accessToken: "Dummy access token", expiresIn: Date(timeIntervalSinceNow: 400 * 24 * 60 * 60))
        handler(ans, nil)
    }
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
final class UnigameModel: CommunicatorDelegate {
    // TODO fill in these delegate stubs, possibly moving to different source file.
    func newPlayerList(_ numPlayers: Int, _ players: [Player]) {

    }
    
    func gameChanged(_ gameState: GameState) {

    }
    
    func error(_ error: any Error, _ deleteGame: Bool) {

    }
    
    func lostPlayer(_ lost: Player) {

    }
    
    func newChatMsg(_ msg: String) {

    }
    
    var tokenProvider: any TokenProvider = DummyTokenProvider()
    
    // Access to UserDefaults settings.
    // We can't (and don't) use @AppStorage here because @Observable doesn't accommodate property wrappers.
    var userName: String = {
        if let ans = UserDefaults.standard.string(forKey: UserNameKey), ans != "" {
            return ans
        }
        // Need to set UserDefaults manually in initializer since didSet will not be called.
        let ans = fakeNames.randomElement()! // fakeNames is not empty, hence the force unwrap is safe
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

    // The Communicator (nil until player search begins; remains non-nil through player searach and during actual play)
    var communicator : Communicator? = nil

    // Indicates that play has begun.  If communicator is non-nil and playBegun is false, the player list is still being
    // constructed.  Game turns may not occur until play officially begins
    var playBegun = false

    // Indicates that the first yield by the leader has occurred.  Until this happens, the leader is allowed to change the
    // setup.  Afterwards, the setup is fixed.  This field is only meaningful in the leader's app instance.
    var setupIsComplete = false
    
    // The transcript of the ongoing chat
    var chatTranscript = ""
    
    // Indicates that chat is enabled
    var chatEnabled: Bool {
        communicator != nil && numPlayers > 1
    }
    
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
    
    // Reset to new game
    func newGame() {
        players = [Player(userName, leadPlayer)]
        thisPlayer = 0
        activePlayer = 0
        communicator = nil
        playBegun = false
        setupIsComplete = false
        chatTranscript = ""
        ensureNumPlayers()
    }
    
    // Start out in the "new game" state
    init() {
        newGame()
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
                // TODO this should be a popup
                Logger.log("Could not establish communication: \(error.localizedDescription)")
            } else {
                Logger.logFatalError("makeCommunicator got unexpected response")
            }
        }
    }
}
