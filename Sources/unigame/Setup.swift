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

struct Setup: View {
    @Environment(UnigameModel.self) var model
    var body: some View {
        Button("Setup Complete", systemImage: "hand.wave") {
            model.transmit()
            model.setupIsComplete = true
        }.buttonStyle(.borderedProminent)
        // Force unwrap should be ok because Setup will not be instantiated when setupView is nil
        AnyView(model.gameHandle.setupView!)
    }
}

#Preview {
    Setup()
        .environment(UnigameModel())
}
