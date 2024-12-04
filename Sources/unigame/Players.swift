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

// This View contains the (unigame standard, game-agnostic) controls for defining yourself
// as a player and connecting with other players in your group.

struct Players: View {
    @Environment(UnigameModel.self) var model
    var body: some View {
        @Bindable var model = model
        VStack {
            Spacer()
            HStack {
                Text("I am:").font(.headline)
                TextField("Player name", text: $model.userName)
                    .onSubmit {
                        model.players[0] = Player(model.userName, model.leadPlayer)
                    }
                Toggle(isOn: $model.leadPlayer) {
                    Text("Leader")
                }
                .onChange(of: model.leadPlayer, initial: false) {
                    model.ensureNumPlayers()
                    model.players[0] = Player(model.userName, model.leadPlayer)
                }
            }
            .border(.black)
            let scope = Toggle(isOn: $model.nearbyOnly) {
                Text("Nearby Only")
            }
            if model.leadPlayer {
                HStack {
                    let stepperMsg = model.solitaireMode ? "single player" : "\(model.numPlayers) players"
                    Stepper(value: $model.numPlayers,
                            in: model.gameHandle.numPlayerRange) {
                        Text(stepperMsg)
                    }.padding(.leading)
                    if !model.solitaireMode {
                        scope
                    }
                }
            } else {
                scope
            }
            if model.solitaireMode {
                Button("Play", systemImage: "figure.play") {
                    model.playBegun = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            } else {
                GameTokensView()
                HStack {
                    Button("Login", systemImage: "dot.radiowaves.left.and.right") {
                        Task { @MainActor in
                            await model.login()
                        }
                    }
                    .disabled(model.nearbyOnly || model.mayConnect)
                    Button("Join", systemImage: "person.line.dotted.person") {
                        Task { @MainActor in
                            await model.connect()
                        }
                    }
                    .disabled((model.gameToken ?? "").isEmpty || model.communicator != nil
                              || (!model.nearbyOnly
                                  && !model.mayConnect))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }
            Spacer()
        }
    }
}

#Preview {
    UserDefaults.standard.setValue(true, forKey: LeadPlayerKey)
    UserDefaults.standard.setValue(2, forKey: NumPlayersKey)
    return Players()
        .environment(UnigameModel())
}
