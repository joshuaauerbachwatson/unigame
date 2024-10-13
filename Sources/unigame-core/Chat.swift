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

struct Chat: View {
    @Environment(UnigameModel.self) var model
    @State private var message = ""
    let lineLimit: Int?

    var body: some View {
        VStack {
            GeometryReader { metrics in
                VStack {
                    HStack {
                        Button(action: sendTouched) {
                            Text("Send")
                        }
                        TextField("message to send", text: $message)
                    }
                    ScrollViewReader { reader in
                        ScrollView {
                            Text(model.chatTranscript)
                                .lineLimit(lineLimit)
                                .id("textId")
                                .frame(width: metrics.size.width)
                                .padding()
                                .border(.black, width: 3)
                        }
                        .onChange(of: model.chatTranscript, initial: true) {
                            reader.scrollTo("textId", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func sendTouched() {
        model.communicator?.sendChatMsg(message)
    }
    
    private func doneTouched() {
        
    }
}

#Preview {
    Chat(lineLimit: nil)
        .environment(UnigameModel())
}
