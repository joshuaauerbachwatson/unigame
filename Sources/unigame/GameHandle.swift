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
    // The TokenProvider
    var tokenProvider: (any TokenProvider)? { get }
    
    // The possible range for number of players
    var numPlayerRange: ClosedRange<Int> { get }
    
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

    // The appId.  When using the server, this is prepended to the game token.
    // When using MultiPeer, this becomes the serviceType, so that game tokens
    // are interpreted only within the scope of a single app.  In both cases it
    // cuts down on the likelihood of collision between unrelated groups.
    // But, because it is also the official MultiPeer service type, it must be declared in InfoPlist:
    //     <key>NSLocalNetworkUsageDescription</key>
    //     <string>Communicate with other players nearby</string>
    //     <key>NSBonjourServices</key>
    //     <array>
    //       <string>_theAppId._tcp</string>
    //       <string>_theAppId._udp</string>
    //     </array>
    var appId: String { get }
}

// A Dummy GameHandle allowing UnigameModel to be instantiated in previews, etc.
// There is no real game logic.
struct DummyGameHandle: GameHandle {
    var tokenProvider: (any TokenProvider)? = nil
    var numPlayerRange: ClosedRange<Int> = 1...6
    func reset(){}
    func stateChanged(_ data: [UInt8]) -> (any Error)? {
        return nil
    }
    func encodeState(duringSetup: Bool) -> [UInt8] {
        [UInt8]()
    }
    var setupView: (any View)? = DummySetup()
    var playingView: any View = DummyPlaying()
    var appId: String = "dummyApp"
}
