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
This tab should contain the appropriate help text and
supporting controls for whatever game is being played.
There will be a common body of text across all games
using the unigame-core, describing the facilities that
are part of the core (finding players, chatting).
This should be augmented by game-specific help text.
"""

struct Help: View {
    var body: some View {
        VStack {
            Spacer()
            Text(description)
            Spacer()
        }
    }
}

#Preview {
    Help()
}
