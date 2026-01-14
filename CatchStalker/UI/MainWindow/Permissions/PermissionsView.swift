import SwiftUI

struct PermissionsView: View {
    @StateObject private var permissions = PermissionsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: permissions.allPermissionsGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(permissions.allPermissionsGranted ? StatusColor.success : StatusColor.warning)
                
                VStack(alignment: .leading) {
                    Text(permissions.allPermissionsGranted ? "All Permissions Granted" : "Some Permissions Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("CatchStalker needs certain permissions to function properly")
                        .foregroundStyle(.secondary)
                }
            }
            
            if !permissions.allPermissionsGranted {
                Text("Modules without required permissions will be disabled until you grant access.")
                    .font(.callout)
                    .foregroundStyle(StatusColor.warning)
                    .padding(.top, Spacing.xs)
            }
        }
    }
    
    private var permissionCardsSection: some View {
        VStack(spacing: Spacing.contentSpacing) {
            PermissionCard(
                title: "Accessibility",
                description: "Required for capturing keyboard and mouse events. Also enable Input Monitoring in System Settings.",
                icon: "accessibility",
                isGranted: permissions.accessibilityGranted,
                requiredBy: ["Keystroke Logger", "Mouse Tracker"],
                onRequest: {
                    permissions.resetRequestFlags()
                    permissions.requestAccessibilityPermission()
                },
                onOpenSettings: { permissions.openSystemPreferencesAccessibility() }
            )
            
            PermissionCard(
                title: "Input Monitoring",
                description: "Required on macOS Catalina+ to capture keyboard input. Add CatchStalker to Input Monitoring in System Settings.",
                icon: "keyboard",
                isGranted: permissions.accessibilityGranted,
                requiredBy: ["Keystroke Logger"],
                onRequest: {
                    permissions.openSystemPreferencesInputMonitoring()
                },
                onOpenSettings: { permissions.openSystemPreferencesInputMonitoring() }
            )
            
            PermissionCard(
                title: "Screen Recording",
                description: "Required for capturing screenshots of your screen",
                icon: "rectangle.dashed.badge.record",
                isGranted: permissions.screenRecordingGranted,
                requiredBy: ["Screenshot Capture"],
                onRequest: {
                    permissions.resetRequestFlags()
                    permissions.requestScreenRecordingPermission()
                },
                onOpenSettings: { permissions.openSystemPreferencesScreenRecording() }
            )
            
            PermissionCard(
                title: "Camera",
                description: "Required for capturing photos from your camera",
                icon: "camera.fill",
                isGranted: permissions.cameraGranted,
                requiredBy: ["Camera Capture"],
                onRequest: {
                    permissions.resetRequestFlags()
                    permissions.requestCameraPermission()
                },
                onOpenSettings: { permissions.openSystemPreferencesCamera() }
            )
        }
    }
    
    private var modulePermissionMappingSection: some View {
        GroupBox("Module Permission Requirements") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ModulePermissionRow(
                    moduleName: "Keystroke Logger",
                    moduleIcon: "keyboard",
                    requiredPermission: "Accessibility + Input Monitoring",
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
            .padding(.vertical, Spacing.sm)
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
    
    @State private var isHovered = false
    
    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: Spacing.contentSpacing) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xl))
                    .foregroundStyle(isGranted ? StatusColor.success : StatusColor.warning)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isGranted ? StatusColor.success : StatusColor.error)
                            Text(isGranted ? "Granted" : "Not Granted")
                                .font(.caption)
                                .foregroundStyle(isGranted ? StatusColor.success : StatusColor.error)
                        }
                    }
                    
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Required by:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(requiredBy, id: \.self) { module in
                            Text(module)
                                .badgeStyle()
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
                        .padding(.top, Spacing.xs)
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(AppAnimation.fast, value: isHovered)
        .onHover { isHovered = $0 }
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
                .foregroundStyle(isEnabled ? .accentColor : StatusColor.inactive)
                .frame(width: IconSize.lg)
            
            Text(moduleName)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(requiredPermission)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? StatusColor.success : StatusColor.error)
        }
    }
}
