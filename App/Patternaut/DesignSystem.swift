import SwiftUI
import IAMJARLDesignTokens

/// The app's own names for the portfolio's design tokens.
///
/// Everything visual that is not the tracker grid itself comes from
/// `iamjarl-design`, so the colour, spacing and radius here are the same ones
/// the site and the other apps use rather than a copy that drifts from them.
/// The grid keeps its own monospaced, high-contrast treatment: it is imitating
/// a piece of hardware, which is a deliberate exception rather than an oversight.
enum Design {
    static func accent(_ scheme: ColorScheme) -> Color { DesignTokens.Common.primary(scheme) }
    static func accentSubtle(_ scheme: ColorScheme) -> Color {
        DesignTokens.pick(DesignTokens.ColorToken.Light.primarySubtle,
                          DesignTokens.ColorToken.Dark.primarySubtle, scheme: scheme)
    }

    enum Space {
        static let xs = DesignTokens.Spacing.xs
        static let sm = DesignTokens.Spacing.sm
        static let md = DesignTokens.Spacing.md
        static let lg = DesignTokens.Spacing.lg
        static let xl = DesignTokens.Spacing.xl
    }

    enum Radius {
        static let sm = DesignTokens.Radius.sm
        static let md = DesignTokens.Radius.md
        static let lg = DesignTokens.Radius.lg
    }
}
