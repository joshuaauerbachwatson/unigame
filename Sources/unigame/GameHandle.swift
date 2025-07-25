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
    // Must have a method that makes a model holding an instance of the GameHandle class
    static func makeModel() -> UnigameModel<Self>
    
    // A back-pointer to the model to be filled in during model initialization.
    // It should be a weak reference to avoid memory issues.
    var model: UnigameModel<Self>? { get set }
    
    // The HelpHandle
    var helpHandle: any HelpHandle { get }
    
    // The possible range for number of players
    var numPlayerRange: ClosedRange<Int> { get }
    
    // The Scoring value to record in the model at the start of the game.
    // The value in the model may subsequently be changed.
    var initialScoring: Scoring { get }
    
    // Called when a new game is started (old game state should be discarded)
    func reset()

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

// A Dummy GameHandle allowing UnigameModel to be instantiated in previews, etc.
// There is no real game logic.
struct DummyGameHandle: GameHandle {
    static func makeModel() -> UnigameModel<DummyGameHandle> {
        let handle = self.init()
        return UnigameModel(gameHandle: handle)
    }
    static func makeModel(defaults: UserDefaults) -> UnigameModel<DummyGameHandle> {
        let handle = self.init()
        return UnigameModel(gameHandle: handle, defaults: defaults)
    }
    var model: UnigameModel<DummyGameHandle>?
    var tokenProvider: (any TokenProvider)? = nil
    var helpHandle: any HelpHandle = NoHelpProvided()
    var numPlayerRange: ClosedRange<Int> = 1...6
    var initialScoring: Scoring = Scoring.Off
    func reset(){}
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
