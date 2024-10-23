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

class MultiPeerCommunicator : NSObject, Communicator, MCNearbyServiceAdvertiserDelegate,
                             MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    // The local "peer id" (encodes the full identity of the player (name and order)
    private let peerId : MCPeerID
    
    // The advertiser object
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    
    // The browser object
    private let serviceBrowser : MCNearbyServiceBrowser
    
    // The service name (used to keep unrelated groups in proximity from interfering).  This is generated from the
    // "game token" by converting underscores to hyphens and truncating at 15 characters.
    private let serviceName : String
    
    // The number of players.  In the leader instance, this is set to its true value during initialization.
    // For non-leaders, it is initially zero (meaning unknown) and is learned as part of discoveryInfo sent by
    // the leader.
    var numPlayers: Int
    
    // The delegate, with which we communicate critical events
    private let delegate : CommunicatorDelegate?
    
    // Send a chat message to all peers
    func sendChatMsg(_ msg: String) {
        if session.connectedPeers.count > 0 {
            Logger.log("Sending new chat message")
            do {
                var buffer: Data = Data([MessageType.Chat.code])
                buffer.append(Data(msg.utf8))
                try session.send(buffer, toPeers: session.connectedPeers, with: .reliable)
            } catch let error {
                delegate?.error(error, false)
            }
        }
    }
    
    // The session as a lazily initialized private property
    private lazy var session : MCSession = {
        let session = MCSession(peer: self.peerId, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        return session
    }()
    
    // Initializer
    init(player: Player, gameToken: String, delegate: CommunicatorDelegate) {
        self.delegate = delegate
        self.peerId = MCPeerID(displayName: player.token)
        self.numPlayers = 0
        self.serviceName = toServiceName(gameToken)
        var info: [String:String]? = nil
        if player.order == UInt32(1) { // leader
            let numPlayers = UserDefaults.standard.integer(forKey: NumPlayersKey)
            self.numPlayers = numPlayers
            info = [ NumPlayersKey : String(numPlayers)]
        }
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: info, serviceType: serviceName)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceName)
        super.init()
        serviceBrowser.delegate = self
        serviceAdvertiser.delegate = self
        Logger.log("Multipeer: starting advertiser and browser")
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    
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
                delegate?.error(error, false)
            }
        }
    }
    
    // Shutdown communications
    func shutdown(_ dueToError: Bool) {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
    }
    
    // Conformance to protocol MCNearbyServiceAdvertiserDelegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        delegate?.error(error, false)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Logger.log("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }

    // Conformance to protocol MCNearbyServiceBrowserDelegate
    // React to error in browsing
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        delegate?.error(error, false)
    }

    // React to found peer
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Logger.log("Peer found: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        // If the peer is the leader, it will have sent along the correct numPlayers value
        if let info = info, let numPlayersString = info[NumPlayersKey], let numPlayers = Int(numPlayersString) {
            self.numPlayers = numPlayers
        }
    }

    // React to losing contact with peer
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Logger.log("Peer lost: \(peerID)")
        if let player = Player(peerID.displayName) {
            delegate?.lostPlayer(player)
        }
    }

    // Conformance to protocol MCSessionDelegate
    // React to state change
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Logger.log("peer \(peerID) didChangeState: \(state)")
        switch state {
        case .notConnected:
            if let player = Player(peerID.displayName) {
                delegate?.lostPlayer(player)
            }
        case .connecting:
            break
        case .connected:
            if self.numPlayers > 0 {
                sendLatestPlayerList()
            }
        @unknown default:
            break
        }
    }
    
    // Send the latest player list based on the session.  This is only called when numPlayers is non-zero
    // (meaning that it is a meaningful value and not "unknown").
    func sendLatestPlayerList() {
        guard let thisPlayer = Player(peerId.displayName) else { return }
        var list: [Player] = [thisPlayer]
        for peer in session.connectedPeers {
            if let player = Player(peer.displayName) {
                list.append(player)
            }
        }
        self.delegate?.newPlayerList(numPlayers, list.sorted())
    }

    // React to incoming data
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let type = MessageType.from(code: data[0]) else {
            Logger.log("Received message of unknown type \(data[0])")
            return
        }
        Logger.log("Received message of type: \(type.display)")
        guard let delegate = self.delegate else {
            Logger.log("Incoming message ignored, no delegate")
            return
        }
        let body = data.suffix(from: 1)
        switch type {
        case .Game:
            let gameState = GameState(body)
            delegate.gameChanged(gameState)
        case .Chat:
            let newMsg = String(decoding: data, as: UTF8.self)
            delegate.newChatMsg(newMsg)
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

// Translate a game token (which can be longer than 15 characters and contain underscores) into a legal
// service name.
fileprivate func toServiceName(_ gameToken: String) -> String {
    let shorter = gameToken.count > 15 ? String(gameToken.prefix(15)) : gameToken
    return shorter.replacingOccurrences(of: "_", with: "-")
}
