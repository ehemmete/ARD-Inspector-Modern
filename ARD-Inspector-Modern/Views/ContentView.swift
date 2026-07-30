import SwiftUI

struct ContentView: View {
    @State var viewModel = ARDViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            if let computer = viewModel.selectedComputer {
                DetailView(computer: computer)
            } else {
                Text("Select a computer to view details")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $viewModel.isPasswordPromptShowing) {
            PasswordPromptView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading ARD Preferences...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("Try Again") {
                viewModel.resetPasswordPrompt()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onAppear {
            Task {
                await viewModel.attemptAutoLogin()
            }
        }

        
    }
}
