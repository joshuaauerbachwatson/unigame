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

fileprivate let description = """
This tab should contain the (unigame standard game-agnostic)
chat dialog, to be used when the primary focus is on
chatting.  A small chat area may also appear in other
tabs.
"""

struct Chat: View {
    @Environment(UnigameModel.self) var modelData
    @State private var message = ""

    var body: some View {
        @Bindable var modelData = modelData
        
        VStack {
            TextField("message to send", text: $message)
            HStack {
                Spacer()
                Button(action: sendTouched) {
                    Text("Send")
                }
                Spacer()
                Button(action: doneTouched) {
                    Text("Done")
                }
                Spacer()
            }
            TextEditor(text: $modelData.chatTranscript)
                .lineLimit(nil)
                .padding()
                    .border(.black, width: 3)
            Spacer()
        }
    }
    
    private func sendTouched() {
        modelData.communicator?.sendChatMsg(message)
    }
    
    private func doneTouched() {
        
    }
}

#Preview {
    Chat()
        .environment(UnigameModel(tokenProvider: DummyTokenProvider()))
}
