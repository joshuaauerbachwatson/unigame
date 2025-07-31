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

struct Chat<T: GameHandle>: View {
    @Environment(UnigameModel<T>.self) var model
    @State private var message = ""
    @FocusState private var sendIsFocused: Bool

    var body: some View {
        Text("Chat With Other Players")
            .font(.largeTitle)
        VStack {
            if let lastUpdate = model.lastChatMsgTime {
                Text("Last message received at \(lastUpdate.formatted())")
            }
            TextField("message to send", text: $message)
                .focused($sendIsFocused)
                .onSubmit {
                    model.sendChatMsg(message)
                    message = ""
                    sendIsFocused = true
                }
                .onAppear {
                    sendIsFocused = true
                }
                .padding()
                .border(.black, width: 3)
            ScrollViewReader { reader in
                ScrollView {
                    let placeHolder = ["No messages yet"]
                    ForEach(model.chatTranscript ?? placeHolder, id: \.self) { line in
                        Text(line)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id("textId")
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .onChange(of: model.chatTranscript, initial: true) {
                    reader.scrollTo("textId", anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    let model = DummyGameHandle.model
    model.chatTranscript = ["[Bob] Hi there", "[Ray] Hello yourself"]
    model.lastChatMsgTime = Date.now
    return Chat<DummyGameHandle>()
        .environment(model)
}
