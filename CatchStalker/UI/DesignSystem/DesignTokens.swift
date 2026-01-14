import SwiftUI

// MARK: - Spacing Scale
/// Consistent spacing values following an 8-point grid system
enum Spacing {
    /// 2pt - Extra extra small
    static let xxs: CGFloat = 2
    /// 4pt - Extra small
    static let xs: CGFloat = 4
    /// 8pt - Small
    static let sm: CGFloat = 8
    /// 12pt - Medium
    static let md: CGFloat = 12
    /// 16pt - Large
    static let lg: CGFloat = 16
    /// 20pt - Extra large
    static let xl: CGFloat = 20
    /// 24pt - Extra extra large
    static let xxl: CGFloat = 24
    /// 32pt - Extra extra extra large
    static let xxxl: CGFloat = 32
    
    // MARK: Semantic Spacing
    /// Section spacing between major content blocks (20pt)
    static let sectionSpacing: CGFloat = xl
    /// Content spacing within sections (16pt)
    static let contentSpacing: CGFloat = lg
    /// Item spacing within lists/groups (12pt)
    static let itemSpacing: CGFloat = md
    /// Inline spacing between related elements (8pt)
    static let inlineSpacing: CGFloat = sm
    /// Card internal padding (16pt)
    static let cardPadding: CGFloat = lg
    /// GroupBox content padding (12pt)
    static let groupBoxContent: CGFloat = md
    /// Form row spacing (16pt)
    static let formRow: CGFloat = lg
    /// Sheet/dialog padding (30pt)
    static let sheetPadding: CGFloat = 30
}

// MARK: - Corner Radius
/// Consistent corner radius values
enum CornerRadius {
    /// 4pt - Small elements (tags, badges)
    static let sm: CGFloat = 4
    /// 8pt - Medium elements (buttons, inputs)
    static let md: CGFloat = 8
    /// 12pt - Large elements (cards, panels)
    static let lg: CGFloat = 12
    /// 16pt - Extra large elements (modals, sheets)
    static let xl: CGFloat = 16
}

// MARK: - Status Colors
/// Semantic colors for status indicators
enum StatusColor {
    /// Success state (green)
    static let success = Color.green
    /// Warning state (orange)
    static let warning = Color.orange
    /// Error/destructive state (red)
    static let error = Color.red
    /// Inactive/disabled state (gray)
    static let inactive = Color.gray
    /// Informational state (blue)
    static let info = Color.blue
    /// Active/running state (green)
    static let active = Color.green
    /// Idle/stopped state (gray)
    static let idle = Color.gray
}

// MARK: - Icon Sizes
/// Consistent icon size values
enum IconSize {
    /// 12pt - Inline icons
    static let xs: CGFloat = 12
    /// 16pt - Small icons
    static let sm: CGFloat = 16
    /// 20pt - Medium icons
    static let md: CGFloat = 20
    /// 24pt - Large icons
    static let lg: CGFloat = 24
    /// 36pt - Feature icons
    static let xl: CGFloat = 36
    /// 48pt - Hero icons
    static let xxl: CGFloat = 48
    /// 60pt - Display icons
    static let xxxl: CGFloat = 60
}

// MARK: - Shadows
/// Consistent shadow styles
enum AppShadow {
    /// Subtle shadow for cards at rest
    static let card = (color: Color.black.opacity(0.08), radius: CGFloat(4), y: CGFloat(2))
    /// Elevated shadow for hovered cards
    static let cardHover = (color: Color.black.opacity(0.15), radius: CGFloat(8), y: CGFloat(4))
    /// Subtle shadow for floating elements
    static let subtle = (color: Color.black.opacity(0.05), radius: CGFloat(3), y: CGFloat(1))
}

// MARK: - Animation
/// Consistent animation values
enum AppAnimation {
    /// Quick transitions (0.15s)
    static let fast = Animation.easeOut(duration: 0.15)
    /// Standard transitions (0.2s)
    static let standard = Animation.easeOut(duration: 0.2)
    /// Slow transitions (0.3s)
    static let slow = Animation.easeOut(duration: 0.3)
}
