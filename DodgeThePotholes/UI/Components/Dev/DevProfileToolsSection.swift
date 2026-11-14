#if DEBUG
import SwiftUI

/// Edits to the real saved profile, each behind a confirmation. Debug builds only.
struct DevProfileToolsSection: View {

    let viewModel: DevMenuViewModel

    @State private var pendingTool: Tool?

    private enum Tool: String, Identifiable {
        case addMoney = "Add $10,000"
        case unlockAll = "Unlock everything"
        case reset = "Reset progress"

        var id: String { rawValue }

        var message: String {
            switch self {
            case .addMoney:  return "Add $10,000 to your real bank?"
            case .unlockAll: return "Unlock every car, song and the tank on your real profile?"
            case .reset:     return "Erase your real money, high score, run history and unlocks? Sound settings are kept."
            }
        }
    }

    var body: some View {
        if viewModel.hasProfileTools {
            Section {
                LabeledContent("Real bank", value: "$\(viewModel.realMoney)")
                ForEach([Tool.addMoney, .unlockAll, .reset]) { tool in
                    Button(tool.rawValue, role: tool == .reset ? .destructive : nil) {
                        pendingTool = tool
                    }
                }
            } header: {
                Text("Real Profile")
            } footer: {
                Text("These change your actual saved progress.")
            }
            .confirmationDialog(pendingTool?.rawValue ?? "", isPresented: isConfirming,
                                titleVisibility: .visible, presenting: pendingTool) { tool in
                Button(tool.rawValue, role: tool == .reset ? .destructive : nil) { run(tool) }
                Button("Cancel", role: .cancel) {}
            } message: { tool in
                Text(tool.message)
            }
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingTool != nil }, set: { if !$0 { pendingTool = nil } })
    }

    private func run(_ tool: Tool) {
        switch tool {
        case .addMoney:  viewModel.addMoney(10_000)
        case .unlockAll: viewModel.unlockEverything()
        case .reset:     viewModel.resetProgress()
        }
    }
}
#endif
