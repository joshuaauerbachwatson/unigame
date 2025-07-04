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


struct HelpWrapper<T: GameHandle>: UIViewControllerRepresentable {
    typealias UIViewControllerType = HelpController
    @Environment(UnigameModel<T>.self) var model

    func makeUIViewController(context: Context) -> HelpController {
        return model.helpController
    }
    
    func updateUIViewController(_ uiViewController: HelpController, context: Context) {
        // TODO; possibly nothing needed here.
    }
}

struct Help<T: GameHandle>: View {
    var body: some View {
        ZStack {
            Color.brown
            HelpWrapper<T>()
                .padding()
        }

    }
}

#Preview {
    Help<DummyGameHandle>()
        .environment(DummyGameHandle.makeModel())
}
