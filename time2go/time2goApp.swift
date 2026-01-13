import SwiftUI
import UIKit

@main
struct time2goApp: App {
    @StateObject private var l10n = LocalizationManager()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // ✅ 修改：删掉强制黑/白判断，直接使用系统默认背景色
        // 这样深色模式就是深灰/黑，浅色模式就是白，完全跟随系统
        appearance.backgroundColor = .systemBackground

        let normalColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .lightGray : .darkGray
        }

        let selectedColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        }

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]
        
        appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
        appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance

        appearance.selectionIndicatorImage = UIImage.selectionPill(
            color: UIColor { trait in
                trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.20, alpha: 1.0)
                : UIColor(white: 0.88, alpha: 1.0)
            }
        )

        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(l10n)
                .environment(\.locale, l10n.locale)
        }
    }
}

extension UIImage {
    static func selectionPill(
        color: UIColor,
        size: CGSize = CGSize(width: 64, height: 36),
        cornerRadius: CGFloat = 18
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.addPath(path.cgPath)
            ctx.cgContext.fillPath()
        }
        return img.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: cornerRadius, left: cornerRadius,
                bottom: cornerRadius, right: cornerRadius
            )
        )
    }
}
