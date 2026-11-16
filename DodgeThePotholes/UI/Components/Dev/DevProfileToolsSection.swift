#if DEBUG
import SwiftUI

/// Edits to the real saved profile: what the Shop and the game's BEST actually use.
/// Shown first in the DEV menu. Adding money is instant; anything that loses progress
/// asks first. Debug builds only.
struct DevProfileToolsSection: View {

    let viewModel: DevMenuViewModel

    @State private var bankText = ""
    @State private var highScoreText = ""
    @State private var pendingTool: Tool?

    private enum Tool: Identifiable {
        case lowerHighScore(Int)
        case resetHighScore
        case unlockAll
        case resetProgress

        var id: String { title }

        var title: String {
            switch self {
            case .lowerHighScore(let score): return "Lower high score to \(score.formatted())"
            case .resetHighScore:            return "Reset high score"
            case .unlockAll:                 return "Unlock everything"
            case .resetProgress:             return "Reset progress"
            }
        }

        var message: String {
            switch self {
            case .lowerHighScore, .resetHighScore: return "Your real best score will go down."
            case .unlockAll:     return "Unlock every car, song and the tank on your real profile?"
            case .resetProgress: return "Erase your real money, high score, run history and unlocks? Sound settings are kept."
            }
        }

        var isDestructive: Bool {
            if case .unlockAll = self { return false }
            return true
        }
    }

    var body: some View {
        if viewModel.hasProfileTools {
            Section {
                bank
                highScore
                Button("Unlock everything") { pendingTool = .unlockAll }
                    .accessibilityIdentifier("dev.unlockAll")
                Button("Reset progress", role: .destructive) { pendingTool = .resetProgress }
                    .accessibilityIdentifier("dev.resetProgress")
            } header: {
                Text("Real Profile")
            } footer: {
                Text("Your actual saved progress: what the Shop and the game's BEST use.")
            }
            .confirmationDialog(pendingTool?.title ?? "", isPresented: isConfirming,
                                titleVisibility: .visible, presenting: pendingTool) { tool in
                Button(tool.title, role: tool.isDestructive ? .destructive : nil) { run(tool) }
                Button("Cancel", role: .cancel) {}
            } message: { tool in
                Text(tool.message)
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var bank: some View {
        LabeledContent("Bank", value: "$\(viewModel.realMoney.formatted())")
            .accessibilityIdentifier("dev.bank")
        HStack {
            ForEach([1_000, 10_000, 100_000], id: \.self) { amount in
                Button("+$\(amount.formatted())") { viewModel.addMoney(amount) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("dev.add\(amount)")
            }
        }
        numberRow("Set bank to…", text: $bankText, id: "dev.setBank") { amount in
            viewModel.setMoney(amount)
        }
    }

    @ViewBuilder
    private var highScore: some View {
        LabeledContent("High score", value: viewModel.realHighScore.formatted())
            .accessibilityIdentifier("dev.highScore")
        numberRow("Set high score to…", text: $highScoreText, id: "dev.setHighScore") { score in
            if score < viewModel.realHighScore {
                pendingTool = .lowerHighScore(score)
            } else {
                viewModel.setHighScore(score)
            }
        }
        Button("Reset high score") { pendingTool = .resetHighScore }
            .accessibilityIdentifier("dev.resetHighScore")
    }

    /// A number field with a Set button; `apply` gets the number and the field clears.
    private func numberRow(_ prompt: String, text: Binding<String>, id: String,
                           apply: @escaping (Int) -> Void) -> some View {
        HStack {
            TextField(prompt, text: text)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("\(id)Field")
            Button("Set") {
                guard let value = Int(text.wrappedValue.filter(\.isNumber)) else { return }
                apply(value)
                text.wrappedValue = ""
            }
            .buttonStyle(.bordered)
            .disabled(Int(text.wrappedValue.filter(\.isNumber)) == nil)
            .accessibilityIdentifier(id)
        }
    }

    // MARK: - Confirmed tools

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingTool != nil }, set: { if !$0 { pendingTool = nil } })
    }

    private func run(_ tool: Tool) {
        switch tool {
        case .lowerHighScore(let score): viewModel.setHighScore(score)
        case .resetHighScore:            viewModel.setHighScore(0)
        case .unlockAll:                 viewModel.unlockEverything()
        case .resetProgress:             viewModel.resetProgress()
        }
    }
}
#endif
