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
        let scope = model.hasTokenProvider ? AnyView(Toggle(isOn: $model.nearbyOnly) {
            Text("Nearby Only")
        }) : AnyView(Text("Nearby Only, Remote Disabled"))
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
            .padding()
            if model.leadPlayer {
                HStack {
                    let stepperMsg = model.solitaireMode ? "single player" : "\(model.numPlayers) players"
                    Stepper(value: $model.numPlayers,
                            in: model.gameHandle.numPlayerRange) {
                        Text(stepperMsg)
                    }
                    Spacer()
                    if !model.solitaireMode {
                        scope
                    }
                }
                .padding()
            } else {
                scope.padding()
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
                    .disabled(model.nearbyOnly || !model.hasTokenProvider || model.hasValidCredentials)
                    let mayNotJoin = (model.gameToken ?? "").isEmpty
                    || (model.communicator != nil) // already joined
                    || (!model.nearbyOnly && !model.hasValidCredentials)
                    Button("Join", systemImage: "person.line.dotted.person") {
                        Task { @MainActor in
                            await model.connect()
                        }
                    }
                    .disabled(mayNotJoin)
                    Button("Logout") {
                        Task { @MainActor in
                            await model.logout()
                        }
                    }
                    .disabled(!model.hasTokenProvider || model.hasValidCredentials)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }
            Spacer()
        }
    }
}

#Preview {
    let defaults = MockDefaults()
    defaults.setValue(true, forKey: LeadPlayerKey)
    defaults.setValue(2, forKey: NumPlayersKey)
    return Players()
        .environment(UnigameModel(defaults: defaults))
}
