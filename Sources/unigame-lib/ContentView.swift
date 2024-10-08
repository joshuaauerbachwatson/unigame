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

struct ContentView: View {
    @Environment(UnigameModel.self) var model
    let setup: any View
    let playing: any View
    var body: some View {
        NavigationStack {
            GeometryReader { metrics in
                VStack {
                    HStack {
                        NavigationLink {
                            Chat()
                        } label: {
                            Label("Expand chat", systemImage: "person.3.sequence")
                            .disabled(model.communicator == nil)
                        }
                        PlayerLabels()
                        NavigationLink {
                            Help()
                        } label: {
                            Label("Help", systemImage: "questionmark.circle")
                        }
                    }.padding()
                        .border(.black, width: 3)
                    Chat()
                        .frame(height: metrics.size.height * 0.15)
                        .disabled(model.communicator == nil)
                    switch (model.phase) {
                    case .Players:
                        Players()
                    case .Setup:
                        Setup(contents: setup)
                    case .Playing:
                        Playing(contents: playing)
                    }
                }
            }
        }
   }
}

#Preview {
    ContentView(setup: DummySetup(), playing: DummyPlaying())
        .environment(UnigameModel())
}
