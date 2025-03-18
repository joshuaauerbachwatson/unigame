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
        Logger.log("Contructing\(dummyName == nil ? "" : " dummy") PlayerLabel with id=\(id)")
        self.id = id
        self.dummyName = dummyName
    }
    
    private func getText() -> String {
        Logger.log("Getting label text for id=\(id)")
        Logger.log("Model has numPlayers=\(model.numPlayers) with a player array count of" +
                   " \(model.players.count)")
        return dummyName ?? (id == model.thisPlayer ? "You" : model.players[id].name)
    }
    
    var body: some View {
        let iconName = id == model.winner ? "star.fill" :
            id == model.activePlayer ? "figure.walk" : "figure.stand"
        HStack {
            Label(getText(), systemImage: iconName)
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
                        @Bindable var bmodel = model
                        Stepper(value: $bmodel.players[id].score) {
                            TextField("score", value: $bmodel.players[id].score, format: IntegerFormatStyle())
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

// A subview to appear near the top of other views (Players, Playing) representing the
// players of the game.  Populated from unigameModel.players and other information.
struct PlayerLabels: View {
    @Environment(UnigameModel.self) var model
    
    var body: some View {
        HStack {
            Spacer()
            ForEach(0..<model.numPlayerLabels, id: \.self) { index in
                model.getPlayerLabel(index)
            }
            Spacer()
        }
    }
}

#Preview {
    PlayerLabels()
        .environment(UnigameModel())
}
