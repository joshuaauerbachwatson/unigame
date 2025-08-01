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

struct Playing<T>: View where T: GameHandle {
    @Environment(UnigameModel<T>.self) var model
    var body: some View {
        if !model.solitaireMode {
            Button("End My Turn", systemImage: "hand.wave") {
                model.yield()
            }.buttonStyle(.borderedProminent)
                .disabled(!model.thisPlayersTurn)
        }
        AnyView(model.gameHandle.playingView)
    }
}

#Preview {
    Playing<DummyGameHandle>()
        .environment(DummyGameHandle.model)
}
