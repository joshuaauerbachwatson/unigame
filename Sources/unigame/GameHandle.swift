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

import SwiftUI

// Each game that uses unigame-model must provide its implementation of this protocol
@MainActor @preconcurrency
public protocol GameHandle {
    // Must return the identical model instance each time until endGame is called
    // A default implementation is provided and should usually be used.
    static var model: UnigameModel<Self> { get }
    
    // A convenient instance method that also gets the model.  A default implementation is
    // provided and should usually be used.
    var model: UnigameModel<Self>? { get }
    
    // A place to cache a model instance for the static model variable to use.  Must be implemented.
    static var savedModel: UnigameModel<Self>? { get set }
    
    // Must have a no-argument initializer
    init()
    
    // The HelpHandle
    var helpHandle: any HelpHandle { get }
    
    // The possible range for number of players
    var numPlayerRange: ClosedRange<Int> { get }
    
    // The Scoring value to record in the model at the start of the game.
    // The value in the model may subsequently be changed.
    var initialScoring: Scoring { get }
    
    // Called when a game ends.  Implementations must set instance to nil and may do other things
    // to cleanup game-specific state.  It is not necessary to return either the model nor the game handle
    // to the initial state because these objects are only reused within a game and are discarded when the
    // game ends.
    func endGame()

    // Called when another player has transmitted new state.
    func stateChanged(_ data: [UInt8]) -> Error?

    // Called in order to obtain the current state of the game for transmission, either
    // during setup or during play.  Note that the duringSetup argument can only be true for
    // lead players since other players do not experience a setup phase.  The flag is a hint
    // to avoid sending things over and over that will not have changed after setup.
    func encodeState(duringSetup: Bool) -> [UInt8]
    
    // The SwiftUI view to use as the main subview during setup.  If nil, there id no setup phase.
    var setupView: (any View)? { get }
    
    // The SwiftUI view to use as the main subview during play
    var playingView: any View { get }

    // The gameId.  When using the server, this is prepended to the group token.
    // When using MultiPeer, this becomes the serviceType, so that group tokens
    // are interpreted only within the scope of a single game.  In both cases it
    // cuts down on the likelihood of collision between unrelated groups.
    // But, because it is also the official MultiPeer service type, it must be declared in InfoPlist:
    //     <key>NSLocalNetworkUsageDescription</key>
    //     <string>Communicate with other players nearby</string>
    //     <key>NSBonjourServices</key>
    //     <array>
    //       <string>_theGameId._tcp</string>
    //       <string>_theGameId._udp</string>
    //       ... repeat for other games in the app
    //     </array>
    // gameId need not be human-friendly.  The gameName field exists for UI purposes.
    var gameId: String { get }
    
    // The human-friendly name for the game
    var gameName: String { get }
}

extension GameHandle {
    public static var model: UnigameModel<Self> {
        if let savedModel {
            return savedModel
        }
        let instance = UnigameModel<Self>(gameHandle: Self.init())
        Self.savedModel = instance
        return instance
    }
    public var model: UnigameModel<Self>? {
        Self.model
    }
}

// A Dummy GameHandle allowing UnigameModel to be instantiated in previews, etc.
// There is no real game logic.
struct DummyGameHandle: GameHandle {
    var model: UnigameModel<DummyGameHandle>?
    static var savedModel: UnigameModel<DummyGameHandle>? = nil
    var tokenProvider: (any TokenProvider)? = nil
    var helpHandle: any HelpHandle = NoHelpProvided()
    var numPlayerRange: ClosedRange<Int> = 1...6
    var initialScoring: Scoring = Scoring.Off
    func endGame(){}
    func stateChanged(_ data: [UInt8]) -> (any Error)? {
        return nil
    }
    func encodeState(duringSetup: Bool) -> [UInt8] {
        [UInt8]()
    }
    var setupView: (any View)? = DummySetup()
    var playingView: any View = DummyPlaying()
    var gameId: String = "dummyGame"
    var gameName: String = "Dummy Game"
}
