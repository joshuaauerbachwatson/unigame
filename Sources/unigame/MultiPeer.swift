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
import MultipeerConnectivity
import AuerbachLook

// Communicator implementation for multi-peer

final class MultiPeerCommunicator : NSObject, Communicator, @unchecked Sendable {
    // The local "peer id" (encodes the full identity of the player (name and order)
    private let peerId : MCPeerID
    
    // The advertiser object
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    
    // The browser object
    private let serviceBrowser : MCNearbyServiceBrowser
    
    // The number of players.  In the leader instance, this is set to its true value during initialization.
    // For non-leaders, it is initially zero (meaning unknown) and is learned as part of discoveryInfo sent by
    // the leader.
    var numPlayers: Int
    
    // The gameToken.  Only peers presenting the matching token in their browser discoveryInfo will be invited.
    private let gameToken: String
    
    // The session as a lazily initialized private property
    private lazy var session : MCSession = {
        let session = MCSession(peer: self.peerId, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        return session
    }()
    
    // Initializer
    init(player: Player, gameToken: String, appId: String) {
        self.peerId = MCPeerID(displayName: player.token)
        self.numPlayers = 0
        self.gameToken = gameToken
        var info: [String:String] = [ GameTokenKey: gameToken ]
        if player.order == UInt32(1) { // leader
            let numPlayers = UserDefaults.standard.integer(forKey: NumPlayersKey)
            self.numPlayers = numPlayers
            info[NumPlayersKey] = String(numPlayers)
        }
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: info, serviceType: appId)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: appId)
        super.init()
        serviceBrowser.delegate = self
        serviceAdvertiser.delegate = self
        Logger.log("Multipeer: starting advertiser and browser")
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }

    var events: AsyncStream<CommunicatorEvent> {
        return AsyncStream<CommunicatorEvent> { continuation in
            self.continuation = continuation
        }
    }
    
    var continuation: AsyncStream<CommunicatorEvent>.Continuation?
    
    // Send the game state to all peers.  A harmless no-op if there are no peers.  Handles errors (when there is at least one
    // peer) by calling delegate.error().   Implements Communicator protocol
    func send(_ gameState : GameState) {
        if session.connectedPeers.count > 0 {
            Logger.log("Sending new game state")
            do {
                var buffer: Data = Data([MessageType.Game.code])
                buffer.append(gameState.encoded())
                try session.send(buffer, toPeers: session.connectedPeers, with: .reliable)
            } catch let error {
                continuation?.yield(.error(error, true))
            }
        }
    }
    
    // Send a chat message to all peers and post to self (but only if sent to at least one other)
    func sendChatMsg(_ msg: String) {
        if session.connectedPeers.count > 0 {
            Logger.log("Sending new chat message")
            do {
                var buffer: Data = Data([MessageType.Chat.code])
                buffer.append(Data(msg.utf8))
                try session.send(buffer, toPeers: session.connectedPeers, with: .reliable)
                continuation?.yield(.newChatMsg(msg))
            } catch let error {
                continuation?.yield(.error(error, false))
            }
        }
    }

    // Shutdown communications
    func shutdown(_ dueToError: Bool) {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
        continuation?.finish()
    }
 }
    
// Conformance to protocol MCNearbyServiceAdvertiserDelegate
extension MultiPeerCommunicator: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        continuation?.yield(.error(error, false))
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Logger.log("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
}

 // Conformance to protocol MCNearbyServiceBrowserDelegate
extension MultiPeerCommunicator: MCNearbyServiceBrowserDelegate {
    // React to error in browsing
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        continuation?.yield(.error(error, false))
    }
    
    // React to found peer
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Logger.log("Peer found: \(peerID)")
        guard let info = info else {
            return
        }
        Logger.log("discoveryInfo is \(info)")
        // If the peer is using the same game token as we are, invite the peer to join.  Otherwise, ignore.
        if info[GameTokenKey] == self.gameToken {
            Logger.log("Matching peer: inviting to join")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        } else {
            Logger.log("Ignoring peer, different game token")
        }
        // If the peer is the leader, it will have sent along the correct numPlayers value
        if let numPlayersString = info[NumPlayersKey], let numPlayers = Int(numPlayersString) {
            Logger.log("Peer is leader.  Recording numPlayers = \(numPlayers)")
            self.numPlayers = numPlayers
        }
    }
    
    // React to losing contact with peer
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Logger.log("Peer lost: \(peerID)")
        if let player = Player(peerID.displayName) {
            continuation?.yield(.lostPlayer(player))
        }
    }
}

// Conformance to protocol MCSessionDelegate
extension MultiPeerCommunicator: MCSessionDelegate {
    // React to state change
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Logger.log("peer \(peerID) didChangeState: \(state)")
        switch state {
        case .notConnected:
            if let player = Player(peerID.displayName) {
                continuation?.yield(.lostPlayer(player))
            }
        case .connecting:
            break
        case .connected:
            if self.numPlayers > 0 {
                reportPlayerList()
            }
        @unknown default:
            break
        }
    }
    
    // Send the latest player list based on the session.  This is only called when numPlayers is non-zero
    // (meaning that it is a meaningful value and not "unknown").
    func reportPlayerList() {
        guard let thisPlayer = Player(peerId.displayName) else { return }
        var list: [Player] = [thisPlayer]
        for peer in session.connectedPeers {
            if let player = Player(peer.displayName) {
                list.append(player)
            }
        }
        continuation?.yield(.newPlayerList(numPlayers, list.sorted()))
    }

    // React to incoming data
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let type = MessageType.from(code: data[0]) else {
            Logger.log("Received message of unknown type \(data[0])")
            return
        }
        Logger.log("Received message of type: \(type.display)")
        let body = [UInt8](data.suffix(from: 1))
        switch type {
        case .Game:
            let gameState = GameState(body)
            continuation?.yield(.gameChanged(gameState))
        case .Chat:
            let newMsg = String(decoding: body, as: UTF8.self)
            continuation?.yield(.newChatMsg(newMsg))
        default:
            Logger.log("No handling defined in MultiPeer communicator for type \(type.display)")
        }
    }

    // React to received stream (not used here but required by protocol)
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        Logger.log("didReceiveStream")
    }

    // React to received resource (not used here but required by protocol)
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Logger.log("didStartReceivingResourceWithName")
    }

    // React to received resource, alternate form (not used here but required by protocol)
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?,
                 withError error: Error?) {
        Logger.log("didFinishReceivingResourceWithName")
    }
}
