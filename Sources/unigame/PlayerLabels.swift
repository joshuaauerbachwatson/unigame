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

fileprivate let MustFind = "[Missing]"
fileprivate let Searching = "[Searching]"

// An individual player label.  May contain a Player or a placeholder value
struct PlayerLabel: View, Identifiable {
    @Environment(UnigameModel.self) var model

    let name: String
    @State var score: String
    let id: Int
    
    private func scoreChanged() {
        if let newScore = UInt32(score) {
            model.changeScore(of: id, to: newScore)
        } else {
            model.displayError("'\(score)' is not a valid score")
        }
    }

    var body: some View {
        let iconName = id == model.winner ? "star.fill" :
            id == model.activePlayer ? "figure.walk" : "figure.stand"
        let text = id == model.thisPlayer ? "You" : name
        HStack {
            Label(text, systemImage: iconName)
                .foregroundStyle(id == model.winner ? .yellow : .black)
            if model.scoring != .Off {
                TextField("Score", text: $score)
                    .onSubmit {
                        scoreChanged()
                    }
                    .fixedSize()
                    .disabled(!model.mayChangeScore(id))
            }
        }
        .padding(.horizontal, 5)
        .border(.black, width: 2)
    }
}

// Function to calculate the PlayerLabel views to show.  Some of these are for real players and some
// are placeholders.
fileprivate func playerArray(_ players: [Player], numPlayers: Int, communicating: Bool) -> [PlayerLabel] {
    var names = players.map { $0.name }
    var scores = players.map {$0.score }
    if numPlayers == 0 && communicating {
        // Non-lead player who does not yet know the player count but is expecting more
        names.append("...expecting more...")
        scores.append(0)
    } else {
        while names.count < numPlayers {
            names.append(communicating ? Searching : MustFind)
            scores.append(0)
        }
    }
    return zip(names, scores).enumerated().map {
        PlayerLabel(name: $0.1.0, score: String($0.1.1), id: $0.0)
    }
}

// A subview to appear near the top of other views (Players, Playing) representing the
// players of the game.  Populated from unigameModel.players and other information.
struct PlayerLabels: View {
    @Environment(UnigameModel.self) var model
    
    var body: some View {
        let content = playerArray(model.players, numPlayers: model.numPlayers, communicating: model.communicator != nil)
        HStack {
            Spacer()
            ForEach(content) { playerLabel in
                playerLabel
            }
            Spacer()
        }
    }
}

#Preview {
    PlayerLabels()
        .environment(UnigameModel())
}
