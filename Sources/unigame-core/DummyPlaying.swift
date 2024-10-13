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
This tab should contain the material of a specific game,
a shared view which is visible to all players.

The unigame-core provides only this placeholder.
In a functioning game, the Playing struct should be
replaced by game-specific code.
"""

struct DummyPlaying: View {
    var body: some View {
        VStack {
            Spacer()
            Text(description)
            Spacer()
        }
    }
}

func DummyGameHandler(_ data: Data)-> LocalizedError? {
    return nil
}

#Preview {
    DummyPlaying()
}
