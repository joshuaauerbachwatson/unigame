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
protocol GameHandle {
    var tokenProvider: any TokenProvider { get }
    func stateChanged(_ data: Data, setup: Bool)->LocalizedError?
    func encodeState(setup: Bool) -> Data
    var setupView: any View { get }
    var playingView: any View { get }
}

// A stand-in for the real token provider, allowing a UnigameModel to be instantiated in previews, etc.
// This does _not_ support communication with the server.
struct DummyTokenProvider: TokenProvider {
    func login(_ handler: @escaping (Credentials?, (any LocalizedError)?) -> ()) {
        let ans = Credentials(accessToken: "", expiresIn: Date(timeIntervalSinceNow: 400 * 24 * 60 * 60))
        handler(ans, nil)
    }
}

// A Dummy GameHandle allowing UnigameModel to be instantiated in previews, etc.  There is no real game logic
struct DummyGameHandle: GameHandle {
    var tokenProvider: any TokenProvider = DummyTokenProvider()
    func stateChanged(_ data: Data, setup: Bool) -> (any LocalizedError)? {
        return nil
    }
    func encodeState(setup: Bool) -> Data {
        Data()
    }
    var setupView: any View = DummySetup()
    var playingView: any View = DummyPlaying()
}
