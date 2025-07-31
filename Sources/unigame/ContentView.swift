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

public struct ContentView<T: GameHandle>: View {
    @Environment(UnigameModel<T>.self) var model
    
    public init() {
        Logger.log("New unigame content view created")
    }

    public var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.presentedViews) {
            VStack {
                Text(model.gameHandle.gameName)
                    .frame(maxWidth: .infinity)
                    .bold().font(.largeTitle)
                    .border(.black, width: 3)
                Spacer()
                HStack {
                    Label("Players:", systemImage: "person.3.sequence")
                    PlayerLabels<T>()
                }
                HStack {
                    if let lastChat = model.chatTranscript?.last, let lastTime =  model.lastChatMsgTime {
                        let text = "At \(lastTime.formatted(date: .omitted, time: .shortened)):  " + lastChat
                        Text(text)
                            .bold()
                            .foregroundStyle(.purple)
                    } else {
                        Text("[no chat messages yet]")
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                }
                HStack {
                    NavigationLink(value: "chat") {
                        Label("Chat", systemImage: "ellipsis.message")
                    }
                    .disabled(model.communicator == nil)
                    Spacer()
                    Button("End Game", systemImage: "xmark.circle.fill") {
                        model.withdraw()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    Spacer()
                    NavigationLink(value: "help") {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
                .navigationDestination(for: String.self) { value in
                    switch value {
                    case "chat":
                        Chat<T>()
                    case "help":
                        Help<T>()
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                
                if !model.playBegun {
                    Players<T>()
                } else if model.setupInProgress {
                    Setup<T>()
                } else {
                    Playing<T>()
                }
            }
            .disabled(model.draining)
            .alert(model.errorTitle, isPresented: $model.showingError) {
                Button("OK") {
                    model.resetError()
                }
            } message: {
                Text(model.errorMessage ?? "Unknown Error")
                if model.errorIsTerminal {
                    Text("Game ending")
                }
            }
        }
   }
}

#Preview {
    ContentView<DummyGameHandle>()
        .environment(DummyGameHandle.model)
}
