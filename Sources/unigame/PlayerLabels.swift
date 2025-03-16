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
import AuerbachLook

fileprivate let MustFind = "[Missing]"
fileprivate let Searching = "[Searching]"

// An individual player label.  May contain a Player or a placeholder value
struct PlayerLabel: View, Identifiable {
    @Environment(UnigameModel.self) var model

    let id: Int
    @State var showPopup: Bool = false
    let dummyName: String?
    
    init(id: Int, dummyName: String? = nil) {
        self.id = id
        self.dummyName = dummyName
    }
    
    var body: some View {
        @Bindable var model = model
        let iconName = id == model.winner ? "star.fill" :
            id == model.activePlayer ? "figure.walk" : "figure.stand"
        let text = dummyName ?? (id == model.thisPlayer ? "You" : model.players[id].name)
        HStack {
            Label(text, systemImage: iconName)
                .foregroundStyle(id == model.winner ? .yellow : .black)
            if model.scoring != .Off && model.playBegun {
                Text(model.players[id].score, format: IntegerFormatStyle())
                    .fixedSize()
                    .foregroundStyle(.red)
                Button("", systemImage: "pencil") {
                    showPopup = true
                }
                .disabled(!model.mayChangeScore(id))
                .popover(isPresented: $showPopup) {
                    VStack {
                        Stepper(value: $model.players[id].score) {
                            TextField("score", value: $model.players[id].score, format: IntegerFormatStyle())
                        }
                        HStack {
                            Button("Done", systemImage: "square.and.arrow.down") {
                                showPopup = false
                                model.transmit()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 5)
        .border(.black, width: 2)
    }
}

// Function to calculate the PlayerLabel views to show.  Some of these are for real players and some
// are placeholders.
@MainActor
fileprivate func playerArray(_ players: [Player], numPlayers: Int, communicating: Bool) -> [PlayerLabel] {
    Logger.log("Building PlayerLabel array with \(players.count) players, numPlayers=\(numPlayers)," +
               " and communicating=\(communicating)")
    var ans = [PlayerLabel]()
    for i in 0..<players.count {
        Logger.log("Making PlayerLabel with id \(i)")
        ans.append(PlayerLabel(id: i))
    }
    if numPlayers == 0 && communicating {
        Logger.log("Appending 'expecting more' indicator")
        // Non-lead player who does not yet know the player count but is expecting more
        ans.append(PlayerLabel(id: ans.count, dummyName: "...expecting more..."))
    } else {
        while ans.count < numPlayers {
            Logger.log("Appending dummy PlayerLayer since player.count < numPlayers")
            ans.append(PlayerLabel(id: ans.count, dummyName: communicating ? Searching : MustFind))
        }
    }
    return ans
}

// A subview to appear near the top of other views (Players, Playing) representing the
// players of the game.  Populated from unigameModel.players and other information.
struct PlayerLabels: View {
    @Environment(UnigameModel.self) var model
    
    var body: some View {
        let content = playerArray(model.players, numPlayers: model.numPlayers, communicating: model.communicator != nil)
        HStack {
            Spacer()
            ForEach(content) { playerLabel in
                playerLabel
            }
            Spacer()
        }
    }
}

#Preview {
    PlayerLabels()
        .environment(UnigameModel())
}
