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

public struct ContentView: View {
    @Environment(UnigameModel.self) var model
    
    public init() {}

    public var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.presentedViews) {
            GeometryReader { metrics in
                VStack {
                    HStack {
                        Label("Players:", systemImage: "person.3.sequence")
                        PlayerLabels()
                    }
                    HStack {
                        NavigationLink(value: "chat") {
                            Label("Chat", systemImage: "ellipsis.message")
                        }
                        .disabled(model.communicator == nil)
                        Spacer()
                        Button("End Game", systemImage: "xmark.circle.fill") {
                            model.newGame()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .disabled(model.communicator == nil)
                        Spacer()
                        NavigationLink(value: "help") {
                            Label("Help", systemImage: "questionmark.circle")
                        }
                    }
                    .navigationDestination(for: String.self) { value in
                        switch value {
                        case "chat":
                            Chat()
                        case "help":
                            Help()
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                    .border(.blue, width: 3)
                    switch (model.phase) {
                    case .Players:
                        Players()
                    case .Setup:
                        Setup()
                    case .Playing:
                        Playing()
                    }
                }
            }
        }
        .alert("Error", isPresented: $model.showingError) {
            Button("OK") {
                model.resetError()
            }
        } message: {
            Text(model.errorMessage ?? "Unknown Error")
            if model.errorIsTerminal {
                Text("Game ending")
            }
        }
        .alert("Incoming chat message", isPresented: $model.chatTranscriptChanged) {
            Button("Ok", action: {})
            Button("Open chat") {
                model.presentedViews.append("chat")
            }
        } message: {
            // "no message" case should not occur but let's not crash the app
            Text(model.chatTranscript?.last ?? "Error: there is no message")
        }
   }
}

#Preview {
    ContentView()
        .environment(UnigameModel())
}
