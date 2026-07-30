import SwiftUI

struct DetailView: View {
    let computer: ARDComputer
    
    var body: some View {
        Form {
            Section("General") {
                DetailRow(label: "Name", value: computer.name)
                DetailRow(label: "Hostname", value: computer.hostname)
                DetailRow(label: "Network Address", value: computer.networkAddress)
                DetailRow(label: "Hardware Address", value: computer.hardwareAddress)
                DetailRow(label: "Serial Number", value: computer.machineSerialNumber)
                DetailRow(label: "OS Version", value: computer.osVersion)
            }
            
            Section("Credentials") {
                DetailRow(label: "Login", value: computer.login)
                DetailRow(label: "Password", value: computer.password, isSecure: true)
            }
        }
        .textSelection(.enabled)
        .formStyle(.grouped)
        .padding()
    }
}

struct DetailRow: View {
    let label: String
    let value: String?
    var isSecure: Bool = false
    @State private var isRevealed = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            if let value = value {
                if isSecure {
                    HStack {
                        Text(isRevealed ? value : "••••••••")
                            .foregroundColor(isRevealed ? .primary : .secondary)
                        
                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24)
                        .help(isRevealed ? "Hide password" : "Show password")
                    }
                } else {
                    Text(value)
                }
            } else {
                Text("N/A")
                    .foregroundColor(.secondary)
            }
        }
    }
}
