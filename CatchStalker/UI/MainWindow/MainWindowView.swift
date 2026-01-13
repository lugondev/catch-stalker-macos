import SwiftUI

struct MainWindowView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var isUnlocked = !PasswordManager.shared.hasPassword()
    @State private var showPasswordPrompt = PasswordManager.shared.hasPassword()
    
    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case logs = "Logs"
        case permissions = "Permissions"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .logs: return "list.bullet.rectangle"
            case .permissions: return "lock.shield"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        Group {
            if showPasswordPrompt && !isUnlocked {
                PasswordPromptView(isUnlocked: $isUnlocked)
            } else {
                mainContent
            }
        }
    }
    
    private var mainContent: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            switch selectedTab {
            case .dashboard:
                DashboardView()
            case .logs:
                LogsView()
            case .permissions:
                PermissionsView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct PasswordPromptView: View {
    @Binding var isUnlocked: Bool
    @State private var password = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("CatchStalker is Protected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your password to view data")
                .foregroundColor(.secondary)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit(verifyPassword)
            
            if showError {
                Text("Incorrect password")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Unlock", action: verifyPassword)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func verifyPassword() {
        if PasswordManager.shared.verifyPassword(password) {
            withAnimation {
                isUnlocked = true
            }
        } else {
            showError = true
            password = ""
        }
    }
}
