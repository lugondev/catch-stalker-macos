import SwiftUI

struct PermissionsView: View {
    @StateObject private var permissions = PermissionsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                permissionCardsSection
                modulePermissionMappingSection
            }
            .padding()
        }
        .navigationTitle("Permissions")
        .onAppear {
            permissions.checkAllPermissions()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: permissions.allPermissionsGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundColor(permissions.allPermissionsGranted ? .green : .orange)
                
                VStack(alignment: .leading) {
                    Text(permissions.allPermissionsGranted ? "All Permissions Granted" : "Some Permissions Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("CatchStalker needs certain permissions to function properly")
                        .foregroundColor(.secondary)
                }
            }
            
            if !permissions.allPermissionsGranted {
                Text("Modules without required permissions will be disabled until you grant access.")
                    .font(.callout)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }
    
    private var permissionCardsSection: some View {
        VStack(spacing: 16) {
            PermissionCard(
                title: "Accessibility",
                description: "Required for capturing keyboard and mouse events",
                icon: "accessibility",
                isGranted: permissions.accessibilityGranted,
                requiredBy: ["Keystroke Logger", "Mouse Tracker"],
                onRequest: { permissions.requestAccessibilityPermission() },
                onOpenSettings: { permissions.openSystemPreferencesAccessibility() }
            )
            
            PermissionCard(
                title: "Screen Recording",
                description: "Required for capturing screenshots of your screen",
                icon: "rectangle.dashed.badge.record",
                isGranted: permissions.screenRecordingGranted,
                requiredBy: ["Screenshot Capture"],
                onRequest: { permissions.requestScreenRecordingPermission() },
                onOpenSettings: { permissions.openSystemPreferencesScreenRecording() }
            )
            
            PermissionCard(
                title: "Camera",
                description: "Required for capturing photos from your camera",
                icon: "camera.fill",
                isGranted: permissions.cameraGranted,
                requiredBy: ["Camera Capture"],
                onRequest: { permissions.requestCameraPermission() },
                onOpenSettings: { permissions.openSystemPreferencesCamera() }
            )
        }
    }
    
    private var modulePermissionMappingSection: some View {
        GroupBox("Module Permission Requirements") {
            VStack(alignment: .leading, spacing: 12) {
                ModulePermissionRow(
                    moduleName: "Keystroke Logger",
                    moduleIcon: "keyboard",
                    requiredPermission: "Accessibility",
                    isEnabled: permissions.accessibilityGranted
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "Mouse Tracker",
                    moduleIcon: "cursorarrow.motionlines",
                    requiredPermission: "Accessibility",
                    isEnabled: permissions.accessibilityGranted
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "Screenshot Capture",
                    moduleIcon: "camera.viewfinder",
                    requiredPermission: "Screen Recording",
                    isEnabled: permissions.screenRecordingGranted
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "Camera Capture",
                    moduleIcon: "camera.fill",
                    requiredPermission: "Camera",
                    isEnabled: permissions.cameraGranted
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "App History",
                    moduleIcon: "app.badge",
                    requiredPermission: "None",
                    isEnabled: true
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "File Access Monitor",
                    moduleIcon: "folder",
                    requiredPermission: "None",
                    isEnabled: true
                )
                
                Divider()
                
                ModulePermissionRow(
                    moduleName: "Clipboard Monitor",
                    moduleIcon: "doc.on.clipboard",
                    requiredPermission: "None",
                    isEnabled: true
                )
            }
            .padding(.vertical, 8)
        }
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let requiredBy: [String]
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(isGranted ? .green : .orange)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isGranted ? .green : .red)
                            Text(isGranted ? "Granted" : "Not Granted")
                                .font(.caption)
                                .foregroundColor(isGranted ? .green : .red)
                        }
                    }
                    
                    Text(description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Required by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(requiredBy, id: \.self) { module in
                            Text(module)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    if !isGranted {
                        HStack {
                            Button("Request Permission") {
                                onRequest()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Open System Settings") {
                                onOpenSettings()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct ModulePermissionRow: View {
    let moduleName: String
    let moduleIcon: String
    let requiredPermission: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: moduleIcon)
                .foregroundColor(isEnabled ? .accentColor : .gray)
                .frame(width: 24)
            
            Text(moduleName)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(requiredPermission)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}
