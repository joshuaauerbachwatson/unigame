//
//  GameTokensView.swift
//  unigame-core
//
//  Created by Josh Auerbach on 9/28/24.
//

import SwiftUI
import AuerbachLook

fileprivate let minTokenLength = 6

struct GameTokensView<T: GameHandle>: View {
    @Environment(UnigameModel<T>.self) var model
    @State private var showingAlert = false
    @State private var newToken = ""
    @State private var tooShort = false
    var body: some View {
        @Bindable var model = model
        VStack {
            HStack {
                Text("Game token:")
                Text(model.gameToken ?? "").bold()
                Spacer()
                Button("Delete", systemImage: "trash") {
                    model.savedTokens.removeAll(where: { $0 == model.gameToken })
                    model.gameToken = ""
                }
                .foregroundStyle(.red)
                Button("Add", systemImage: "plus") {
                    newToken = ""
                    showingAlert = true
                }
                .alert("Enter new game token", isPresented: $showingAlert) {
                    TextField("Enter new game token", text: $newToken)
                        .onChange(of: newToken, initial: false) { former, current in
                            if !validChars(current) {
                                newToken = former
                            }
                        }
                    Button("OK") {
                        if newToken.count >= minTokenLength {
                            model.gameToken = newToken
                            model.savedTokens.append(newToken)
                        } else {
                            tooShort = true
                        }
                    }
                }
                .alert("Game tokens must be at least \(minTokenLength) characters", isPresented: $tooShort) {
                }
            }.padding()
            if (model.gameToken ?? "").isEmpty {
                Text("A game token is required")
                    .foregroundStyle(.red)
            }
            Menu {
                ForEach(model.savedTokens, id: \.self) { token in
                    Button(token) {
                        model.gameToken = token
                    }
                }
            } label: {
                Label("Saved Game Tokens", systemImage: "square.and.arrow.up.fill")
            }.padding()
        }
    }
    
    private func validChars(_ chars: String) -> Bool {
        return (try? Regex("^[a-zA-Z0-9_-]*$").wholeMatch(in: chars)) != nil
    }
}

#Preview {
    let tokens = ["wox123", "flox123", "boxesofbeans"]
    let defaults = MockDefaults()
    defaults.set(tokens, forKey: SavedTokensKey)
    defaults.set("wox", forKey: GameTokenKey)
    return GameTokensView<DummyGameHandle>()
        .environment(DummyGameHandle.makeModel())
}
