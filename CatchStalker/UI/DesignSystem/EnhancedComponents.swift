import SwiftUI

// MARK: - Enhanced GroupBox
/// A GroupBox with optional hover effects and consistent styling
struct EnhancedGroupBox<Content: View>: View {
    let title: String?
    let showHoverEffect: Bool
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    init(
        _ title: String? = nil,
        showHoverEffect: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHoverEffect = showHoverEffect
        self.content = content
    }
    
    var body: some View {
        Group {
            if let title = title {
                GroupBox(title) {
                    content()
                        .padding(.vertical, Spacing.sm)
                }
            } else {
                GroupBox {
                    content()
                        .padding(.vertical, Spacing.sm)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(.clear)
                .shadow(
                    color: isHovered ? AppShadow.subtle.color.opacity(0.12) : AppShadow.subtle.color,
                    radius: isHovered ? 6 : AppShadow.subtle.radius
                )
        )
        .scaleEffect(showHoverEffect && isHovered ? 1.005 : 1.0)
        .animation(AppAnimation.fast, value: isHovered)
        .onHover { hovering in
            if showHoverEffect {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Section Header
/// A consistent section header with optional action button
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var action: (() -> Void)? = nil
    var actionIcon: String = "plus"
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Empty State View
/// A consistent empty state placeholder
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: IconSize.xl))
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.cardPadding)
    }
}

// MARK: - Form Row
/// A consistent form row with label and control
struct FormRow<Content: View>: View {
    let label: String
    var description: String? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
    }
}

// MARK: - Destructive Button Style
/// A button style for destructive actions
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StatusColor.error)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}
