import SwiftUI

struct PasswordPromptView: View {
    @Bindable var viewModel: ARDViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ARD Inspector")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Please enter the master password used by Apple Remote Desktop to decrypt the stored credentials.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            SecureField("Master Password", text: $viewModel.masterPassword)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onSubmit {
                    Task {
                        await viewModel.loadPreferences()
                        viewModel.isPasswordPromptShowing = false
                    }
                }
            
            Toggle("Remember password", isOn: $viewModel.shouldSavePassword)
                .frame(maxWidth: 300)
                .toggleStyle(.checkbox)
            
            HStack {
                Button("Cancel") {
                    viewModel.isPasswordPromptShowing = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Login") {
                    Task {
                        await viewModel.loadPreferences()
                        viewModel.isPasswordPromptShowing = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 450, height: 350)
    }
}
