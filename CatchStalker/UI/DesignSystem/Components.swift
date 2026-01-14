import SwiftUI

// MARK: - Card Style Modifier
/// A reusable card style with hover effects and consistent styling
struct CardStyle: ViewModifier {
    var accentColor: Color = .accentColor
    var showHoverEffect: Bool = true
    
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(.regularMaterial)
                    .shadow(
                        color: isHovered ? AppShadow.cardHover.color : AppShadow.card.color,
                        radius: isHovered ? AppShadow.cardHover.radius : AppShadow.card.radius,
                        y: isHovered ? AppShadow.cardHover.y : AppShadow.card.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(accentColor.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
            )
            .scaleEffect(showHoverEffect && isHovered ? 1.02 : 1.0)
            .animation(AppAnimation.standard, value: isHovered)
            .onHover { hovering in
                if showHoverEffect {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Stat Card Style
/// A specialized card style for statistic cards with icon and value
struct StatCardStyle: ViewModifier {
    let color: Color
    
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(.regularMaterial)
                    .shadow(
                        color: isHovered ? AppShadow.cardHover.color : AppShadow.card.color,
                        radius: isHovered ? AppShadow.cardHover.radius : AppShadow.card.radius,
                        y: isHovered ? AppShadow.cardHover.y : AppShadow.card.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(AppAnimation.standard, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a card style with optional hover effects
    func cardStyle(color: Color = .accentColor, showHoverEffect: Bool = true) -> some View {
        modifier(CardStyle(accentColor: color, showHoverEffect: showHoverEffect))
    }
    
    /// Applies a stat card style optimized for dashboard statistics
    func statCardStyle(color: Color) -> some View {
        modifier(StatCardStyle(color: color))
    }
}

// MARK: - Badge Style
/// A small badge/tag style for labels
struct BadgeStyle: ViewModifier {
    var color: Color = .accentColor
    
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

extension View {
    /// Applies a badge style for tags and labels
    func badgeStyle(color: Color = .accentColor) -> some View {
        modifier(BadgeStyle(color: color))
    }
}

// MARK: - Status Indicator
/// A small circular status indicator
struct StatusIndicator: View {
    let isActive: Bool
    var activeColor: Color = StatusColor.active
    var inactiveColor: Color = StatusColor.inactive
    var size: CGFloat = 8
    
    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: size, height: size)
    }
}

// MARK: - Icon Badge
/// An icon with a colored background
struct IconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = IconSize.xl
    var iconScale: CGFloat = 0.44
    
    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.md)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: size * iconScale, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
