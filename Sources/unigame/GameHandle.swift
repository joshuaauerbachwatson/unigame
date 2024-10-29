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
public protocol GameHandle {
    // The TokenProvider
    var tokenProvider: any TokenProvider { get }
    
    // The possible range for number of players
    var numPlayerRange: ClosedRange<Int> { get }

    // Called when another player has transmitted new state (either during setup or during play.
    func stateChanged(_ data: Data, duringSetup: Bool)->LocalizedError?

    // Called in order to obtain the current state of the game for transmission, either during setup or during play
    func encodeState(duringSetup: Bool) -> Data
    
    // The SwiftUI view to use as the main subview during setup.  If nil, there id no setup phase.
    var setupView: (any View)? { get }
    
    // The SwiftUI view to use as the main subview during play
    var playingView: any View { get }

    // The appId.  When using the server, this is prepended to the game token.  When using MultiPeer, this becomes
    // the serviceType, so that game tokens are interpreted only within the scope of a single app.  In both cases it
    // cuts down on the likelihood of collision between unrelated grouops.  But, because it is also the official
    // MultiPeer service type, it must be declared in InfoPlist:
    //     <key>NSLocalNetworkUsageDescription</key>
    //     <string>Communicate with other players nearby</string>
    //     <key>NSBonjourServices</key>
    //     <array>
    //       <string>_theAppId._tcp</string>
    //       <string>_theAppId._udp</string>
    //     </array>
    var appId: String { get }
}

// A stand-in for the real token provider, allowing a UnigameModel to be instantiated in previews, etc.
// This does _not_ support communication with the server.
struct DummyTokenProvider: TokenProvider {
    func login() async -> (Credentials?, (any LocalizedError)?) {
        let ans = Credentials(accessToken: "", expiresIn: Date(timeIntervalSinceNow: 400 * 24 * 60 * 60))
        return (ans, nil)
    }
}

// A Dummy GameHandle allowing UnigameModel to be instantiated in previews, etc.  There is no real game logic
struct DummyGameHandle: GameHandle {
    var tokenProvider: any TokenProvider = DummyTokenProvider()
    var numPlayerRange: ClosedRange<Int> = 1...6
    func stateChanged(_ data: Data, duringSetup: Bool) -> (any LocalizedError)? {
        return nil
    }
    func encodeState(duringSetup: Bool) -> Data {
        Data()
    }
    var setupView: (any View)? = DummySetup()
    var playingView: any View = DummyPlaying()
    var appId: String = "dummyApp"
}
