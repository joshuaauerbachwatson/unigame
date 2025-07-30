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

import Testing
import Foundation
import SwiftUI
@testable import unigame

@Suite(.serialized) @MainActor struct UnigameModelTests {
    let model: UnigameModel<TestGameHandle>
    
    final class TestGameHandle: GameHandle {
        init() {}
        
        static func makeModel() -> unigame.UnigameModel<TestGameHandle> {
            UnigameModel<TestGameHandle>(gameHandle: TestGameHandle())
        }
        
        var model: unigame.UnigameModel<UnigameModelTests.TestGameHandle>?
        
        var helpHandle: any unigame.HelpHandle = NoHelpProvided()
        
        var initialScoring: unigame.Scoring = .Off
        
        var resetCalled = false
        var lastState: [UInt8]? = nil
        var encodedState: [UInt8] = []
        let numPlayerRange: ClosedRange<Int> = 1...2
        let setupView: (any View)? = DummySetup()
        let playingView: any View = DummyPlaying()
        let gameId: String = "unigametestapp"
        let gameName: String = "Unigame Test App"

        func reset() {
            resetCalled = true
        }
        
        func stateChanged(_ data: [UInt8]) -> (any Error)? {
            lastState = data
            return nil
        }
        
        func encodeState(duringSetup: Bool) -> [UInt8] {
            return encodedState
        }
    }

    // Assume a standard set of user defaults are in place for all tests
    init() {
        let ud = MockDefaults()
        ud.set("Elmer Fudd", forKey: UserNameKey)
        ud.set(true, forKey: LeadPlayerKey)
        ud.set(2, forKey: NumPlayersKey)
        ud.set(true, forKey: NearbyOnlyKey)
        ud.set("Test_Token", forKey: GroupTokenKey)
        ud.set(["Test_Token"], forKey: SavedTokensKey)
        model = UnigameModel(gameHandle: TestGameHandle(), defaults: ud)
    }

    // Test that the initial instantiation of a UnigameModel meets expectations
    @Test("UnigameModel instantiated") @MainActor func UnigameModelTest() {
        #expect(model.userName == "Elmer Fudd")
        #expect(model.leadPlayer)
        #expect(model.numPlayers == 2)
        #expect(model.nearbyOnly)
        #expect(model.groupToken == "Test_Token")
        #expect(model.savedTokens == ["Test_Token"])
        #expect(!model.setupIsComplete)
        #expect(!model.chatEnabled)
        #expect(!model.errorIsTerminal)
        #expect(!model.hasValidCredentials)
        #expect(!model.playBegun)
        #expect(!model.setupInProgress)
        #expect(!model.solitaireMode)
        #expect(!model.showingError)
        #expect(model.thisPlayersTurn)
        #expect(model.communicator == nil)
        #expect(model.activePlayer == 0)
        #expect(model.players == [Player("Elmer Fudd", true)])
        #expect(model.thisPlayer == 0)
        #expect(model.chatTranscript == nil)
        #expect(model.credentials == nil)
        #expect(model.errorMessage == nil)
        #expect(model.helpHandle is NoHelpProvided)
    }
}
