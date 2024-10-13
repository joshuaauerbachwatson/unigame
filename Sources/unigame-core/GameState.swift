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

import UIKit

// Represents the state of a game from the perspective of unigame-core.  This really comes down to which player is
// sending and which is active (ie, whose turn it is).  The "real" game state is in the gameInfo field, which is
// opaque in this context.

struct GameState: Equatable {
    let sendingPlayer : Int  // The index of the player constructing the GameState
    let activePlayer: Int    // The index of the player whose turn it is (== previous except when yielding)
    let setup: Data?         // Information relevant to the setup view (opaque here)
    let gameInfo : Data      // Information relevant to the playing view
    
    // Since I provided a hand-crafted init below, I have to also provide the usually auto-generated one
    init(sendingPlayer: Int, activePlayer: Int, setup: Data?, gameInfo: Data) {
        self.sendingPlayer = sendingPlayer
        self.activePlayer = activePlayer
        self.setup = setup
        self.gameInfo = gameInfo
    }
    
    init(_ encoded: Data) {
        sendingPlayer = Int(encoded[0])
        activePlayer = Int(encoded[1])
        let setupLen = Int(encoded[3])
        var infoStart: Int
        if setupLen == 0 {
            setup = nil
            infoStart = 4
        } else {
            infoStart = 4 + setupLen
            setup = encoded[4..<infoStart]
            
        }
        gameInfo = encoded.suffix(from: infoStart)
    }
    
    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.gameInfo == rhs.gameInfo
        && lhs.sendingPlayer == rhs.sendingPlayer
        && lhs.activePlayer == rhs.activePlayer
        && lhs.setup == rhs.setup
    }
    
    // Returns an encoded GameState
    func encoded() -> Data {
        if let setupLen = setup?.count {
            return Data([UInt8(sendingPlayer), UInt8(activePlayer), UInt8(setupLen)]) + setup! + gameInfo
        } else {
            return Data([UInt8(sendingPlayer), UInt8(activePlayer), UInt8(0)]) + gameInfo
        }
    }
}
