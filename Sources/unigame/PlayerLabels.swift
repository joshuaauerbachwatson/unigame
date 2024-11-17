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

fileprivate let MustFind = "[Must Find]"
fileprivate let Searching = "[Searching]"

// Structure for information about players.
struct PlayerName: Identifiable {
    let id: Int
    let display: String
}

// Function to calculate player name information to go in the labels
fileprivate func playerNames(_ players: [Player], numPlayers: Int, communicating: Bool) -> [PlayerName] {
    var names = players.map { $0.name }
    while names.count < numPlayers {
        names.append(communicating ? Searching : MustFind)
    }
    return names.enumerated().map { PlayerName(id: $0.0, display: $0.1) }
}

// A subview to appear near the top of other views (Players, Playing) representing the
// players of the game.  Populated from unigameModel.players and other information.
struct PlayerLabels: View {
    @Environment(UnigameModel.self) var model
    
    var body: some View {
        let content = playerNames(model.players, numPlayers: model.numPlayers, communicating: model.communicator != nil)
        HStack {
            Spacer()
            ForEach(content) { player in
                let iconName = player.id == model.activePlayer ? "figure.walk" : "stop"
                Label(player.display, systemImage: iconName)
                    .foregroundStyle(player.id == model.thisPlayer ? .green : .black)
                    .padding(.horizontal, 5)
                    .border(.black, width: 2)
            }
            Spacer()
        }
    }
}

#Preview {
    PlayerLabels()
        .environment(UnigameModel())
}
