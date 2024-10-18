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
protocol Communicator {
    func sendChatMsg(_ mag: String)
    func send(_ gameState: GameState)
    func shutdown(_ dueToError: Bool)
}

// The protocol for the delegate (callbacks)
protocol CommunicatorDelegate {
    var  tokenProvider: TokenProvider { get } // Only used by server-based communicator
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
func makeCommunicator(nearbyOnly: Bool, player: Player, gameToken: String, delegate: CommunicatorDelegate,
                      handler: @escaping (Communicator?, LocalizedError?)->Void) {
    if nearbyOnly {
        handler(MultiPeerCommunicator(player: player, gameToken: gameToken, delegate: delegate), nil)
    } else {
        CredentialStore().loginIfNeeded(delegate.tokenProvider) { (credentials, error) in
            if let accessToken = credentials?.accessToken {
                handler(ServerBasedCommunicator(accessToken, gameToken: gameToken, player: player, delegate: delegate), nil)
            } else if let error = error {
                handler(nil, error)
            } else {
                Logger.logFatalError("Login result was neither credentials nor error")
            }
        }
    }
}
