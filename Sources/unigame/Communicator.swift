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
import AuerbachLook

// Basic support for game communication.  Two implementations exist.
// 1.  Multi-peer (proximity).
// 2.  Backend with volatile state (using DigitalOcean App Platform).

// The protocol implemented by all Communicator implementations
protocol Communicator: Sendable {
    func sendChatMsg(_ mag: String)
    func send(_ gameState: GameState)
    func shutdown(_ dueToError: Bool)
    var events: AsyncStream<CommunicatorEvent> { get }
}

// Events that can be sent out of the Communicator via its events channel
enum CommunicatorEvent {
    case newPlayerList(Int, [Player])
    case gameChanged(GameState)
    case error(Error, Bool)
    case lostPlayer(Player)
    case newChatMsg(String)
}

// A convenient dispatcher for events flowing from the Communicator
protocol CommunicatorDispatcher {
    func newPlayerList(_ numPlayers: Int, _ players: [Player])
    func gameChanged(_ gameState: GameState)
    func error(_ error: Error, _ deleteGame: Bool)
    func lostPlayer(_ lost: Player)
    func newChatMsg(_ msg: String)
}

// One-byte message types for use in messages.
// The server-based communicator uses all four to discriminate incoming websocket traffic.
// Both communicators use .Chat and .Game to discriminate sent and received messages.
enum MessageType: Unicode.Scalar, CaseIterable {
    case Chat = "C", Game = "G", Players = "P", LostPlayer = "L"
    var code: UInt8 {
        return UInt8(rawValue.value)
    }

var display: String {
        switch self {
        case .Chat:
            return "CHAT"
        case .Game:
            return "GAME"
        case .Players:
            return "PLAYER LIST"
        case .LostPlayer:
            return "LOST PLAYER"
        }
    }
     
    static func from(rawValue: Unicode.Scalar) ->MessageType? {
        return allCases.filter({ $0.rawValue == rawValue }).first
    }
    
    static func from(code: UInt8) ->MessageType? {
        let rawValue = Unicode.Scalar(code)
        return from(rawValue: rawValue)
    }
}

// Global function to create a communicator of given kind
func makeCommunicator(nearbyOnly: Bool,
                      player: Player,
                      gameToken: String,
                      appId: String,
                      accessToken: String?) async -> Communicator {
    if nearbyOnly {
        return MultiPeerCommunicator(player: player, gameToken: gameToken, appId: appId)
    } else {
        let compositeToken = appId + "_" + gameToken
        guard let accessToken = accessToken else {
            Logger.logFatalError("Server communicator construction attempted with no accessToken available")
        }
        return ServerBasedCommunicator(accessToken, gameToken: compositeToken, player: player)
    }
}
