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

import Foundation
import AuerbachLook

// Constants mimic those in the backend
fileprivate let argGameToken   = "gameToken"
fileprivate let argPlayer      = "player"
fileprivate let argPlayers     = "players"
fileprivate let argGameState   = "gameState"
fileprivate let argError       = "argError"
fileprivate let playerKey      = "Player"
fileprivate let gameKey        = "GameToken"
fileprivate let numPlayersKey  = "NumPlayers"
fileprivate let websocketURL   = "wss://unigame-befsi.ondigitalocean.app/websocket"
fileprivate let ignoredReceiveErrors: [Int] = [ Int(ENOTCONN), Int(ECANCELED) ]

// This communicator uses websocket communication with the server.  Things that may be sent to the server
//  -- chat messages
//  -- new game states
// Things that may be received from the server
// -- chat messages
// -- new game states
// -- lost player messages
// -- player lists
// The connection to the server may also be shutdown, which has consequences for the game as viewed by the
// server and other players.
final class ServerBasedCommunicator : NSObject, Communicator, URLSessionWebSocketDelegate, @unchecked Sendable {
    // Internal state
    private let gameToken: String
    private let accessToken: String
    private let player: Player
    private var webSocketTask: URLSessionWebSocketTask! // Initialized after super call

    private var lastGameState: GameState? = nil
    
    var events: AsyncStream<CommunicatorEvent> {
        return AsyncStream<CommunicatorEvent> { continuation in
            self.continuation = continuation
        }
    }
    
    var continuation: AsyncStream<CommunicatorEvent>.Continuation?
    
    // The initializer to use for this Communicator.  Accepts a gameToken and player and starts listening
    init(player: Player, numPlayers: Int, game: String, appId: String, accessToken: String) {
        self.accessToken = accessToken
        self.gameToken = appId + "_" + game
        self.player = player
        super.init()
        self.webSocketTask = connectWebsocket(game: gameToken, player: player, numPlayers: numPlayers, accessToken: accessToken)
    }

    // Process a new Received state
    private func processReceivedState(_ newState: GameState) {
        if newState != self.lastGameState {
            self.lastGameState = newState
            continuation?.yield(.gameChanged(newState))
        } // do nothing if no change
    }

    // Send a new game state (part of Communicator protocol)
    func send(_ gameState: GameState) {
        var buffer: Data = Data([MessageType.Game.code])
        buffer.append(gameState.encoded())
        Logger.log("Sending game state message of length \(buffer.count)")
        let message = URLSessionWebSocketTask.Message.data(buffer)
        webSocketTask.send(message) { error in
            if let error = error {
                self.continuation?.yield(.error(error, true))
            }
        }
    }
    
    // Shutdown this communicator by disconnecting the websocket.
    // Part of communicator protocol
    func shutdown(_ dueToError: Bool) {
        if webSocketTask.state != URLSessionTask.State.running {
            return
        }
        disconnectWebsocket(dueToError)
    }

    // Subroutine to initialize the websocket connection
    private func connectWebsocket(game: String, player: Player, numPlayers: Int,
                                  accessToken: String) -> URLSessionWebSocketTask {
        Logger.log("New websocket connection with game=\(game), player=\(player.token)")
        var numPlayersQuery = ""
        if player.order == UInt32(1) {
            // Leader
            Logger.log("This player is the leader.  Adding number of players to the request")
            numPlayersQuery = "&\(numPlayersKey)=\(numPlayers)"
        }
        let url = URL(string: "\(websocketURL)?\(gameKey)=\(game)&\(playerKey)=\(player.token)\(numPlayersQuery)")!
        Logger.log("Request URL is \(url)")
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask.delegate = self
        webSocketTask.receive(completionHandler: onWebsocketReceive)
        webSocketTask.resume()
        return webSocketTask
    }
    
    // Subroutine to disconnect the websocket
    private func disconnectWebsocket(_ dueToError: Bool) {
        let code = dueToError ? URLSessionWebSocketTask.CloseCode.protocolError :
            URLSessionWebSocketTask.CloseCode.normalClosure
        webSocketTask.cancel(with: code, reason: nil)
    }
    
    // Completion handler for websocket receive.  If success, posts a new receive.  In either case, processes the present
    // message.
    private func onWebsocketReceive(incoming: Result<URLSessionWebSocketTask.Message, Error>) {
        if case .success(let message) = incoming {
            webSocketTask.receive(completionHandler: onWebsocketReceive)
            onWebsocketMessage(message: message)
        }
        else if case .failure(let error) = incoming {
            Logger.log("Error receiving message: \(error)")
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && ignoredReceiveErrors.contains(nsError.code){
                return
            }
            continuation?.yield(.error(error, true))
        }
    }
    
    // Handles a message received on the websocket
    private func onWebsocketMessage(message: URLSessionWebSocketTask.Message) {
        // The message type may be either string or data.  At the protocol level these are both just bytes
        // but the Task code will have encoded to String if it thinks it's getting text.  We undo this here and
        // treat everything like a byte array.
        switch message {
        case .data(let data):
            processIncomingFromWebsocket(data)
        case .string(let text):
            if let data = text.data(using: .utf8) {
                processIncomingFromWebsocket(data)
            }
        default:
            Logger.logFatalError("Unanticipated incoming message type")
        }
    }
  
    // Process incoming information from websocket
    private func processIncomingFromWebsocket(_ rawData: Data) {
        guard let type = MessageType.from(code: rawData[0]) else {
            Logger.logFatalError("Protocol error.  Unknown message type \(rawData[0])")
        }
        Logger.log("Message of type \(type.display) received on websocket")
        let data = rawData.dropFirst()
        switch type {
        case .Chat:
            continuation?.yield(.newChatMsg(String(decoding: data, as: UTF8.self)))
        case .Game:
            deliverReceivedState(data)
        case .Players:
            deliverPlayerList(data)
        case .LostPlayer:
            deliverLostPlayer(data)
        }
    }
    
    // Decodes and then processes received game state
    private func deliverReceivedState(_ data: Data) {
        let received = GameState([UInt8](data))
        processReceivedState(received)
    }
    
    // Decodes and then processes received player list
    private func deliverPlayerList(_ data: Data) {
        if let coded = String(data: data, encoding: .utf8), let answer = decodePlayers(coded) {
            let (numPlayers, players) = answer
            continuation?.yield(.newPlayerList(numPlayers, players))
        }
    }
    
    // Decodes and then processes received lost player message
    private func deliverLostPlayer(_ data: Data) {
        if let lost = String(data: data, encoding: .utf8), let player = Player(lost) {
            continuation?.yield(.lostPlayer(player))
        }
    }
    
    // Send a chat message.  Part of the Communicator protocol
    func sendChatMsg(_ text: String) {
        let toSend = String(MessageType.Chat.rawValue) + text
        let message = URLSessionWebSocketTask.Message.string(toSend)
        webSocketTask.send(message) { error in
            if let error = error {
                self.continuation?.yield(.error(error, true))
            }
        }
    }
    
    // Conform to URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Logger.log("Web socket task has closed")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Logger.log("Web socket task has opened")
    }
}

struct Disconnection: LocalizedError {
    let closeCode: URLSessionWebSocketTask.CloseCode
    let reason: Data?
    var errorDescription: String {
        let code: String
        switch closeCode {
        case .abnormalClosure:
            code = "abnormalClosure"
        case .invalid:
            code = "invalid"
        case .normalClosure:
            code = "normalClosure"
        case .goingAway:
            code = "goingAway"
        case .protocolError:
            code = "protocolError"
        case .unsupportedData:
            code = "unsupportedData"
        case .noStatusReceived:
            code = "noStatueReceived"
        case .invalidFramePayloadData:
            code = "invalidFramePayloadData"
        case .policyViolation:
            code = "policyViolation"
        case .messageTooBig:
            code = "messageTooBig"
        case .mandatoryExtensionMissing:
            code = "mandatoryExtensionMissing"
        case .internalServerError:
            code = "internalServerError"
        case .tlsHandshakeFailure:
            code = "tlsHandshakeFailure"
        @unknown default:
            code = "unknown"
        }
        var reasonMsg = ""
        if let data = reason, let reasonText = String(data: data, encoding: .utf8) {
            reasonMsg = " ,reason=\(reasonText)"
        }
        return "Websocket closed, code=\(code)\(reasonMsg)"
    }
}
