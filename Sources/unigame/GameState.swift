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

// Represents the state of a game from the perspective of the unigame core.  This includes
// which player is sending and which is active (ie, whose turn it is).  We also send the scores if
// the game is being scored.  The game-specific state is in the gameInfo field, which is opaque in this
// context.

struct GameState: Equatable {
    let sendingPlayer : Int  // The index of the player constructing the GameState
    let activePlayer: Int    // The index of the player whose turn it is (== previous except when yielding)
    let scores: [Int32]      // The current scores (empty if scoring is .Off)
    let gameInfo : [UInt8]   // The information being transmitted, meaningful to the game actually being played
    
    // Since I provided a hand-crafted init below, I have to also provide the usually auto-generated one
    init(sendingPlayer: Int, activePlayer: Int, gameInfo: [UInt8], scores: [Int32] = []) {
        self.sendingPlayer = sendingPlayer
        self.activePlayer = activePlayer
        self.gameInfo = gameInfo
        self.scores = scores
    }
    
    // Initialize GameState from received encoded data
    init(_ encoded: [UInt8]) {
        sendingPlayer = Int(encoded[0])
        activePlayer = Int(encoded[1])
        let scoreCount = Int(encoded[2])
        var buffer = encoded.dropFirst(3)
        var offset = 0
        var scores = [Int32]()
        for i in 0..<scoreCount {
            let nextScore = buffer.withUnsafeBytes { rawBuffer in
                rawBuffer.load(fromByteOffset: offset, as: Int32.self)
            }
            scores.append(nextScore)
            offset += 4
        }
        self.scores = scores
        gameInfo = [UInt8](encoded.suffix(from: offset))
    }
    
    // Conform to Equatable protocol
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.gameInfo == rhs.gameInfo
        && lhs.sendingPlayer == rhs.sendingPlayer
        && lhs.activePlayer == rhs.activePlayer
    }
    
    // Returns an encoded GameState
    func encoded() -> Data {
        if scores.count == 0 {
            return Data([UInt8(sendingPlayer), UInt8(activePlayer), UInt8(0)] + gameInfo)
        }
        var scoreData = [UInt8]()
        for score in scores {
            let array = withUnsafeBytes(of: score, Array.init)
            scoreData += array
        }
        return Data([UInt8(sendingPlayer), UInt8(activePlayer), UInt8(scores.count)] + scoreData + gameInfo)
    }
}
