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

// This tab contains the (unigame standard game-agnostic) controls for defining yourself as a player and connecting
// with other players in your group.

struct Players: View {
    @Environment(UnigameModel.self) var model
    var body: some View {
        @Bindable var model = model
        VStack {
            HStack {
                Text("My player name:").font(.headline)
                TextField("Player name", text: $model.userName)
                    .onSubmit {
                        model.players[0] = Player(model.userName, model.leadPlayer)
                    }
                Toggle(isOn: $model.leadPlayer) {
                    Text("I am leader")
                }
                .onChange(of: model.leadPlayer, initial: false) {
                    model.ensureNumPlayers()
                    model.players[0] = Player(model.userName, model.leadPlayer)
                }
            }.padding().border(.black)
            let scope = Toggle(isOn: $model.nearbyOnly) {
                Text("Nearby Only")
            }
            if model.leadPlayer {
                HStack {
                    Stepper(value: $model.numPlayers,
                            in: 0...6) {
                        Text("\(model.numPlayers) players")
                    }.padding().border(.black)
                    scope
                }
            } else {
                scope
            }
            GameTokensView()
            Button("Connect", systemImage: "dot.radiowaves.left.and.right") {
                model.connect()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .disabled((model.gameToken ?? "").isEmpty)
        }
    }
}

#Preview {
    UserDefaults.standard.setValue(true, forKey: LeadPlayerKey)
    UserDefaults.standard.setValue(2, forKey: NumPlayersKey)
    return Players()
        .environment(UnigameModel())
}
