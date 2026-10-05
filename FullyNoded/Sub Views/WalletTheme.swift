//
//  WalletTheme.swift
//  FullyNoded
//
//  App-wide cypherpunk theme (moved out of ActiveWalletViewController.swift).
//

import UIKit

/// Cypherpunk teal / black theme for the wallet screen and every screen that branches off
/// it (send, invoice, UTXOs, wallet creation, wallets list, transaction verifier...).
/// Same structure as the green `Cypher` palette (home, wallet detail) and the purple
/// `SignerTheme` (signers).
///
/// Most screens are storyboard-built, so instead of rewriting each one the theme walks a
/// view hierarchy and restyles standard UIKit controls in place:
///  - `WalletTheme.apply(to: self, tint:)` at the end of `viewDidLoad`
///  - `WalletTheme.styleCell(_:tint:)` from `tableView(_:willDisplay:forRowAt:)`
///  - `WalletTheme.styleHeader(_:tint:)` from `tableView(_:willDisplayHeaderView:forSection:)`
///  - `WalletTheme.stylePrimary(_:tint:)` for a screen's main action button
enum WalletTheme {

    /// Per-screen accent, all within the teal family so the wallet flow reads as one place.
    enum Tint {
        case wallet, send, receive, utxo, create, transaction, settings, home, signer

        var accent: UIColor {
            switch self {
            case .wallet, .transaction:
                return UIColor(red: 0.18, green: 0.96, blue: 0.88, alpha: 1)   // teal
            case .send:
                return UIColor(red: 0.22, green: 0.86, blue: 1.0, alpha: 1)    // cyan-teal
            case .receive:
                return UIColor(red: 0.32, green: 1.0, blue: 0.74, alpha: 1)    // mint-teal
            case .utxo:
                return UIColor(red: 0.14, green: 0.88, blue: 0.80, alpha: 1)   // deep teal
            case .create:
                return UIColor(red: 0.30, green: 0.93, blue: 0.96, alpha: 1)   // aqua
            case .settings:
                return UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1)    // terminal amber
            case .home:
                return UIColor(red: 0.25, green: 1.0, blue: 0.48, alpha: 1)    // terminal green
            case .signer:
                return SignerTheme.accent                                      // deep purple
            }
        }

        /// Body text / secondary text for this palette (the signer screens have their own
        /// purple-gray ones).
        var text: UIColor { self == .signer ? SignerTheme.text : WalletTheme.text }
        var dim: UIColor { self == .signer ? SignerTheme.dim : WalletTheme.dim }

        var line: UIColor { accent.withAlphaComponent(0.45) }
    }

    /// Corner radius for cards, cells, fields and buttons: square, so 1pt borders stay
    /// crisp all the way into the corners.
    static let radius: CGFloat = 0

    // MARK: Square corners

    /// Inset-grouped tables round the corners of the first / last cell in every section by
    /// setting a corner radius on the cell's layer (which also clips the cell). That clipped
    /// our 1pt card borders at the corners. This keeps a view's layer square: it resets the
    /// radius immediately whenever UIKit changes it. Safe to call repeatedly (one guard per view).
    static func squareCorners(_ view: UIView) {
        view.layer.cornerRadius = radius
        guard objc_getAssociatedObject(view, squareGuardKey) == nil else { return }
        objc_setAssociatedObject(view, squareGuardKey, SquareCornerGuard(layer: view.layer), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static let squareGuardKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// Watches a layer's corner radius and puts it back to `WalletTheme.radius`.
    private final class SquareCornerGuard: NSObject {
        private var observation: NSKeyValueObservation?

        init(layer: CALayer) {
            super.init()
            observation = layer.observe(\.cornerRadius, options: [.new]) { layer, _ in
                if layer.cornerRadius != WalletTheme.radius {
                    layer.cornerRadius = WalletTheme.radius
                }
            }
        }

        deinit { observation?.invalidate() }
    }

    static let bg = UIColor(red: 0.02, green: 0.04, blue: 0.045, alpha: 1)      // near-black, teal tint
    static let card = UIColor(red: 0.05, green: 0.09, blue: 0.095, alpha: 1)    // dark teal-gray
    static let line = Tint.wallet.line                                          // teal border
    static let accent = Tint.wallet.accent                                      // teal neon
    static let dim = UIColor(red: 0.42, green: 0.62, blue: 0.62, alpha: 1)      // muted teal-gray
    static let text = UIColor(red: 0.80, green: 0.95, blue: 0.94, alpha: 1)     // pale aqua
    static let outgoing = UIColor(red: 1.0, green: 0.36, blue: 0.48, alpha: 1)  // hot pink-red
    static let pending = UIColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 1)   // amber
    static let danger = UIColor(red: 1.0, green: 0.28, blue: 0.32, alpha: 1)

    /// Marks a button as the screen's primary (solid) action, so re-styling keeps it filled.
    private static let primaryMarker = "WalletTheme.primary"
    /// Tag on the padding view we add to text fields (so it's only added once).
    private static let fieldPaddingTag = 0x57A1

    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// Monospaced version of `font`, same size and (roughly) the same weight.
    static func mono(from font: UIFont?, fallbackSize: CGFloat = 14) -> UIFont {
        guard let font = font else { return mono(fallbackSize) }
        var weight = UIFont.Weight.regular
        if let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
           let raw = traits[.weight] as? CGFloat {
            weight = UIFont.Weight(rawValue: raw)
        }
        if font.fontDescriptor.symbolicTraits.contains(.traitBold), weight.rawValue < UIFont.Weight.semibold.rawValue {
            weight = .semibold
        }
        return mono(font.pointSize, weight: weight)
    }

    // MARK: Colour mapping

    /// Maps any colour (system or custom) into the palette, keeping its meaning:
    /// grays → text / dim, reds → danger, oranges / yellows → amber, everything else → accent.
    static func mapped(_ color: UIColor?, tint: Tint = .wallet) -> UIColor {
        guard let color = color else { return text }
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolved.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return text }
        if a < 0.05 { return color }
        // The screen's own accent stays the accent (amber would otherwise read as "pending").
        var accentHue: CGFloat = 0, accentSaturation: CGFloat = 0
        if s >= 0.35,
           tint.accent.getHue(&accentHue, saturation: &accentSaturation, brightness: nil, alpha: nil),
           abs(h - accentHue) < 0.02 {
            return tint.accent
        }
        if s < 0.35 {
            return (b * a) > 0.72 ? text : dim
        }
        if h < 0.04 || h > 0.9 { return danger }
        if h < 0.18 { return pending }
        return tint.accent
    }

    // MARK: Screens

    /// Restyles a whole screen: background, navigation bar, and every control in it.
    static func apply(to vc: UIViewController, tint: Tint = .wallet) {
        vc.overrideUserInterfaceStyle = .dark
        vc.view.backgroundColor = bg
        vc.view.tintColor = tint.accent
        styleNavigation(vc.navigationItem, tint: tint)
        let items = (vc.navigationItem.leftBarButtonItems ?? []) + (vc.navigationItem.rightBarButtonItems ?? [])
        for item in items {
            item.tintColor = mapped(item.tintColor ?? tint.accent, tint: tint)
            if let customView = item.customView { style(customView, tint: tint) }
        }
        // A UITableViewController's root view IS its table (no container to inset it in).
        if let table = vc.view as? UITableView {
            styleRootTable(table)
        }
        for sub in vc.view.subviews {
            style(sub, tint: tint)
        }
    }

    /// The table that is a UITableViewController's root view: same look as other tables,
    /// but it can't be inset by constraints, so its cards are inset 16pt instead
    /// (`styleCell` reads the marker).
    static func styleRootTable(_ table: UITableView) {
        objc_setAssociatedObject(table, rootTableKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        styleTable(table)
    }

    private static let rootTableKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    // MARK: Tab bar

    /// Cypherpunk tab bar: opaque near-black bar, a faint top hairline, dim icons, and each
    /// tab's selected icon in that section's own accent (home green, wallet teal, signers
    /// purple, settings amber). The colours are baked into the items' images, so they're
    /// right however a tab gets selected (including `selectedIndex` set in code). Safe to
    /// call more than once.
    static func styleTabBar(_ tabBarController: UITabBarController) {
        let tabBar = tabBarController.tabBar
        tabBar.overrideUserInterfaceStyle = .dark

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bg
        appearance.shadowColor = UIColor(white: 1, alpha: 0.10)
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = dim
            layout.normal.titleTextAttributes = [.foregroundColor: dim, .font: mono(10)]
            layout.selected.iconColor = Tint.home.accent
            layout.selected.titleTextAttributes = [.foregroundColor: Tint.home.accent, .font: mono(10, weight: .semibold)]
        }
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = Tint.home.accent
        tabBar.unselectedItemTintColor = dim

        let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
        for controller in tabBarController.viewControllers ?? [] {
            guard let item = controller.tabBarItem else { continue }
            let tint = tabTint(for: controller)
            // Keep the storyboard symbol as the template, so restyling never re-tints a tinted copy.
            let base: UIImage?
            if let stored = objc_getAssociatedObject(item, tabImageKey) as? UIImage {
                base = stored
            } else {
                base = item.image
                if let image = base {
                    objc_setAssociatedObject(item, tabImageKey, image, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            guard let image = base else { continue }
            item.image = image.withTintColor(dim, renderingMode: .alwaysOriginal)
            item.selectedImage = image.applyingSymbolConfiguration(symbolConfiguration)?
                .withTintColor(tint.accent, renderingMode: .alwaysOriginal)
                ?? image.withTintColor(tint.accent, renderingMode: .alwaysOriginal)
        }
    }

    private static let tabImageKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// The accent of the section a tab opens.
    private static func tabTint(for controller: UIViewController) -> Tint {
        let root = (controller as? UINavigationController)?.viewControllers.first ?? controller
        switch root {
        case is MainMenuViewController: return .home
        case is ActiveWalletViewController: return .wallet
        case is SignersViewController: return .signer
        case is SettingsViewController: return .settings
        default: return .send   // nodeless wallets: cyan-teal
        }
    }

    /// Per-screen navigation bar look (set on the navigationItem, so it doesn't leak into
    /// screens with their own palettes).
    static func styleNavigation(_ item: UINavigationItem, tint: Tint = .wallet) {
        let appearance = navigationAppearance(background: bg, line: tint.line, accent: tint.accent)
        appearance.doneButtonAppearance = appearance.buttonAppearance
        setNavigationAppearance(appearance, on: item)
    }

    /// Opaque cypherpunk bar: `background`, a `line` hairline, monospaced `accent` titles
    /// and bar buttons. Shared with the signer screens' palette (SignerTheme).
    static func navigationAppearance(background: UIColor, line: UIColor, accent: UIColor) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = line
        appearance.titleTextAttributes = [.foregroundColor: accent, .font: mono(15, weight: .semibold)]
        appearance.largeTitleTextAttributes = [.foregroundColor: accent, .font: mono(28, weight: .semibold)]

        let buttons = UIBarButtonItemAppearance()
        buttons.normal.titleTextAttributes = [.foregroundColor: accent, .font: mono(15)]
        appearance.buttonAppearance = buttons
        appearance.backButtonAppearance = buttons
        return appearance
    }

    /// Uses `appearance` for every bar state of `item`.
    static func setNavigationAppearance(_ appearance: UINavigationBarAppearance, on item: UINavigationItem) {
        item.standardAppearance = appearance
        item.scrollEdgeAppearance = appearance
        item.compactAppearance = appearance
    }

    /// Restyles `view` and everything inside it.
    static func style(_ view: UIView, tint: Tint = .wallet) {
        switch view {
        case let cell as UITableViewCell:
            styleCell(cell, tint: tint)
        case let table as UITableView:
            styleTable(table)
        case let collection as UICollectionView:
            collection.backgroundColor = .clear
        case let label as UILabel:
            label.font = mono(from: label.font)
            label.textColor = mapped(label.textColor, tint: tint)
            styleContainer(label, tint: tint)
        case let button as UIButton:
            styleButton(button, tint: tint)
        case let field as UITextField:
            styleField(field, tint: tint)
        case let textView as UITextView:
            styleTextView(textView, tint: tint)
        case let toggle as UISwitch:
            toggle.onTintColor = tint.accent
            toggle.thumbTintColor = text
        case let slider as UISlider:
            slider.minimumTrackTintColor = tint.accent
            slider.maximumTrackTintColor = tint.line
            slider.thumbTintColor = tint.accent
        case let control as UISegmentedControl:
            style(control, tint: tint)
        case let spinner as UIActivityIndicatorView:
            spinner.color = tint.accent
        case let progress as UIProgressView:
            progress.progressTintColor = tint.accent
            progress.trackTintColor = tint.line
        case let imageView as UIImageView:
            // Only recolour symbol / template images (not QR codes or photos).
            if imageView.image == nil || imageView.image?.isSymbolImage == true || imageView.image?.renderingMode == .alwaysTemplate {
                imageView.tintColor = mapped(imageView.tintColor, tint: tint)
            }
        case let picker as UIDatePicker:
            picker.tintColor = tint.accent
        case is UIPickerView:
            break
        case let blur as UIVisualEffectView:
            blur.effect = nil
            blur.backgroundColor = bg.withAlphaComponent(0.96)
            blur.layer.borderWidth = 0
            blur.contentView.subviews.forEach { style($0, tint: tint) }
        case let scroll as UIScrollView:
            if scroll.backgroundColor != nil { scroll.backgroundColor = .clear }
            scroll.indicatorStyle = .white
            scroll.subviews.forEach { style($0, tint: tint) }
        default:
            styleContainer(view, tint: tint)
            view.subviews.forEach { style($0, tint: tint) }
        }
    }

    /// Tables: transparent, no separators, and (for grouped / plain tables) inset 16pt from
    /// the screen edges so the full-width cards keep a margin.
    ///
    /// Wallet tables use the "grouped" style rather than "inset grouped": inset-grouped
    /// tables round and clip each section's corners, which cuts off the corners of the
    /// cards' 1pt borders. Cells are styled as they're displayed (willDisplay), not here.
    static func styleTable(_ table: UITableView) {
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.indicatorStyle = .white
        table.layer.cornerRadius = 0
        if #available(iOS 15.0, *) { table.sectionHeaderTopPadding = 0 }
        if table.style == .grouped, table.tableHeaderView == nil {
            // Grouped tables otherwise add ~35pt of empty space at the top.
            table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        }
        if table.style != .insetGrouped {
            insetHorizontally(table, by: 16)
        }
    }

    /// Changes leading / trailing constraints that pin `view` flush (constant 0) to its
    /// container so it sits `inset` points in instead. Constraints with a margin already
    /// are left alone, and it only ever runs once per view.
    private static func insetHorizontally(_ view: UIView, by inset: CGFloat) {
        guard objc_getAssociatedObject(view, insetKey) == nil, let container = view.superview else { return }
        objc_setAssociatedObject(view, insetKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        for constraint in container.constraints where abs(constraint.constant) < 1 && constraint.relation == .equal {
            if constraint.firstItem === view {
                if constraint.firstAttribute == .leading { constraint.constant = inset }
                if constraint.firstAttribute == .trailing { constraint.constant = -inset }
            } else if constraint.secondItem === view {
                if constraint.secondAttribute == .leading { constraint.constant = -inset }
                if constraint.secondAttribute == .trailing { constraint.constant = inset }
            }
        }
    }

    private static let insetKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// Plain container views: coloured backgrounds become cards, rounded / bordered ones
    /// get the thin teal border, and hairlines become teal hairlines.
    private static func styleContainer(_ view: UIView, tint: Tint) {
        let hasBackground: Bool = {
            guard let color = view.backgroundColor else { return false }
            var a: CGFloat = 0
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getWhite(nil, alpha: &a)
            return a > 0.05
        }()
        let size = view.bounds.size
        let isHairline = hasBackground && size != .zero && min(size.width, size.height) <= 2

        if isHairline {
            view.backgroundColor = tint.line
            return
        }
        if hasBackground {
            view.backgroundColor = card
        }
        if view.layer.cornerRadius > 0 || view.layer.borderWidth > 0 {
            view.layer.cornerRadius = radius
            view.layer.borderWidth = 1
            view.layer.borderColor = tint.line.cgColor
        }
    }

    static func style(_ control: UISegmentedControl, tint: Tint = .wallet) {
        styleSegmented(control, background: card, accent: tint.accent, text: dim, selectedText: bg)
    }

    /// Monospaced segmented control in any palette (shared with SignerTheme).
    static func styleSegmented(_ control: UISegmentedControl, background: UIColor, accent: UIColor, text: UIColor, selectedText: UIColor) {
        control.backgroundColor = background
        control.selectedSegmentTintColor = accent
        control.setTitleTextAttributes([.font: mono(12), .foregroundColor: text], for: .normal)
        control.setTitleTextAttributes([.font: mono(12, weight: .semibold), .foregroundColor: selectedText], for: .selected)
    }

    // MARK: Buttons

    /// Solid accent button: use for the one main action on a screen.
    static func stylePrimary(_ button: UIButton, tint: Tint = .wallet) {
        button.layer.name = primaryMarker
        styleButton(button, tint: tint)
    }

    static func styleButton(_ button: UIButton, tint: Tint = .wallet) {
        // Hero buttons are fully styled by `styleHero`; leave them alone.
        guard button.layer.name != heroMarker else { return }
        let isPrimary = button.layer.name == primaryMarker

        if var config = button.configuration {
            // Only real, visible text counts as a title: storyboard / xib icon buttons can carry
            // an empty attributed title, and those must stay borderless icons.
            let plainTitle = config.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let attributedTitle = config.attributedTitle.map { String($0.characters) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Interface Builder's placeholder "Button" title on an image button is not a real
            // title either (it's never shown once the configuration has an image).
            let isPlaceholder = config.image != nil && (plainTitle == "Button" || attributedTitle == "Button")
            let hasTitle = (!plainTitle.isEmpty || !attributedTitle.isEmpty) && !isPlaceholder
            let color = isPrimary ? tint.accent : mapped(config.baseForegroundColor ?? button.tintColor, tint: tint)

            guard hasTitle else {
                // Icon-only button.
                config.baseForegroundColor = color
                config.background.backgroundColor = .clear
                config.background.strokeWidth = 0
                config.background.strokeColor = .clear
                button.configuration = config
                button.backgroundColor = .clear
                button.layer.borderWidth = 0
                return
            }

            config.baseForegroundColor = isPrimary ? bg : color
            config.background.backgroundColor = isPrimary ? color : card
            config.background.strokeColor = isPrimary ? color : color.withAlphaComponent(0.45)
            config.background.strokeWidth = 1
            config.background.cornerRadius = radius
            config.cornerStyle = .fixed
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attributes = incoming
                let size = (incoming.font?.pointSize).map { min($0, 15) } ?? 13
                attributes.font = WalletTheme.mono(size, weight: .semibold)
                return attributes
            }
            button.configuration = config
            button.layer.cornerRadius = radius
            return
        }

        // Legacy (non-configuration) buttons.
        let color = isPrimary ? tint.accent : mapped(button.currentTitleColor, tint: tint)
        let hasTitle = !(button.currentTitle ?? button.currentAttributedTitle?.string ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        button.tintColor = isPrimary ? tint.accent : mapped(button.tintColor, tint: tint)
        if let font = button.titleLabel?.font {
            button.titleLabel?.font = mono(from: font)
        }

        let hasBackground: Bool = {
            guard let bgColor = button.backgroundColor else { return false }
            var a: CGFloat = 0
            bgColor.getWhite(nil, alpha: &a)
            return a > 0.05
        }()

        if isPrimary {
            button.backgroundColor = tint.accent
            button.setTitleColor(bg, for: .normal)
            button.tintColor = bg
            button.layer.borderWidth = 0
            button.layer.cornerRadius = radius
        } else if hasTitle && (hasBackground || button.layer.cornerRadius > 0 || button.layer.borderWidth > 0) {
            button.backgroundColor = card
            button.setTitleColor(color, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = color.withAlphaComponent(0.45).cgColor
            button.layer.cornerRadius = radius
        } else {
            button.setTitleColor(color, for: .normal)
            if hasBackground { button.backgroundColor = .clear }
            if button.layer.cornerRadius > 0 { button.layer.cornerRadius = radius }
        }
        button.setTitleColor(dim, for: .disabled)
    }

    private static let heroMarker = "WalletTheme.hero"

    /// The big call-to-action at the bottom of a screen (e.g. "Create transaction"):
    /// solid accent slab, uppercase spaced monospace label, trailing arrow, soft neon glow,
    /// darker while pressed and a dim outlined look while disabled.
    static func styleHero(_ button: UIButton, title: String, systemImage: String = "arrow.right", tint: Tint = .wallet) {
        button.layer.name = heroMarker
        button.backgroundColor = .clear
        button.clipsToBounds = false
        button.layer.cornerRadius = radius
        button.layer.borderWidth = 0

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.background.cornerRadius = radius
        config.image = UIImage(systemName: systemImage,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)

        var attributed = AttributedString(title.uppercased())
        attributed.font = mono(15, weight: .bold)
        attributed.kern = 2
        config.attributedTitle = attributed
        button.configuration = config

        button.configurationUpdateHandler = { button in
            guard var config = button.configuration else { return }
            if !button.isEnabled {
                config.baseForegroundColor = WalletTheme.dim
                config.background.backgroundColor = WalletTheme.card
                config.background.strokeColor = tint.line
                config.background.strokeWidth = 1
                button.layer.shadowOpacity = 0
            } else {
                let pressed = button.isHighlighted
                config.baseForegroundColor = WalletTheme.bg
                config.background.backgroundColor = pressed ? tint.accent.withAlphaComponent(0.7) : tint.accent
                config.background.strokeWidth = 0
                button.layer.shadowOpacity = pressed ? 0.15 : 0.45
            }
            button.configuration = config
        }

        // Neon glow.
        button.layer.shadowColor = tint.accent.cgColor
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = .zero
        button.layer.shadowOpacity = 0.45
        button.setNeedsUpdateConfiguration()
    }

    /// Makes `button` a bare icon: no fill, no border, accent (or mapped) tint.
    static func styleIconButton(_ button: UIButton, tint: Tint = .wallet) {
        let color = mapped(button.configuration?.baseForegroundColor ?? button.tintColor, tint: tint)
        if var config = button.configuration {
            config.baseForegroundColor = color
            config.background.backgroundColor = .clear
            config.background.strokeWidth = 0
            config.background.strokeColor = .clear
            button.configuration = config
        }
        button.tintColor = color
        button.backgroundColor = .clear
        button.layer.borderWidth = 0
    }

    /// Bordered square button for the wallet's action row. `filled` = primary action.
    static func buttonConfiguration(title: String, systemImage: String, filled: Bool, tint: Tint = .wallet) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: systemImage,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        config.baseForegroundColor = filled ? bg : tint.accent
        config.background.backgroundColor = filled ? tint.accent : card
        config.background.strokeColor = filled ? tint.accent : tint.line
        config.background.strokeWidth = 1
        config.background.cornerRadius = radius
        config.cornerStyle = .fixed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(13, weight: .semibold)
            return attributes
        }
        return config
    }

    /// Small outlined, monospaced button: chips (Paste / Wallet / …) and inline actions
    /// ("Sign", "verify owner", "edit").
    static func chipConfiguration(title: String,
                                  systemImage: String? = nil,
                                  tint: Tint = .wallet,
                                  fontSize: CGFloat,
                                  imageSize: CGFloat,
                                  imagePadding: CGFloat,
                                  insets: NSDirectionalEdgeInsets,
                                  background: UIColor = WalletTheme.card,
                                  clipsTitle: Bool = false) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        if let systemImage = systemImage {
            config.image = UIImage(systemName: systemImage,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: imageSize, weight: .semibold))
            config.imagePadding = imagePadding
        }
        if clipsTitle { config.titleLineBreakMode = .byClipping }
        config.contentInsets = insets
        config.baseForegroundColor = tint.accent
        config.background.backgroundColor = background
        config.background.strokeColor = tint.line
        config.background.strokeWidth = 1
        config.background.cornerRadius = radius
        config.cornerStyle = .fixed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(fontSize, weight: .semibold)
            return attributes
        }
        return config
    }

    // MARK: Cards and captions (screens built in code)

    /// "> TITLE" section caption: 11pt bold monospaced, in the accent colour.
    static func caption(_ text: String, tint: Tint = .wallet) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = mono(11, weight: .bold)
        label.textColor = tint.accent
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    /// Bordered card (square corners) holding `rows` in a vertical stack, 12pt padding.
    static func cardView(_ rows: [UIView], tint: Tint = .wallet, spacing: CGFloat = 10, background: UIColor? = nil) -> UIView {
        let card = UIView()
        card.backgroundColor = background ?? WalletTheme.card
        card.layer.borderWidth = 1
        card.layer.borderColor = tint.line.cgColor
        card.layer.cornerRadius = radius

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    /// Small accent icon button for section headers.
    static func iconButton(_ systemName: String, target: Any, action: Selector, tint: Tint = .wallet) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName,
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                        for: .normal)
        button.tintColor = tint.accent
        button.addTarget(target, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

    // MARK: Text input

    static func styleField(_ field: UITextField, tint: Tint = .wallet) {
        let size = field.font?.pointSize ?? 15
        field.borderStyle = .none
        field.backgroundColor = card
        field.textColor = text
        field.tintColor = tint.accent
        field.font = mono(size)
        field.keyboardAppearance = .dark
        field.layer.cornerRadius = radius
        field.layer.borderWidth = 1
        field.layer.borderColor = tint.line.cgColor
        if let placeholder = field.placeholder {
            field.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                             attributes: [.foregroundColor: dim, .font: mono(size)])
        }
        // Inner padding + a sensible minimum height now that the rounded border is gone.
        if field.leftView == nil {
            let padding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            padding.tag = fieldPaddingTag
            field.leftView = padding
            field.leftViewMode = .always
            let minHeight = field.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
            minHeight.priority = UILayoutPriority(760)
            minHeight.isActive = true
        }
    }

    static func styleTextView(_ textView: UITextView, tint: Tint = .wallet) {
        textView.backgroundColor = card
        textView.textColor = mapped(textView.textColor, tint: tint)
        textView.tintColor = tint.accent
        textView.font = mono(from: textView.font)
        textView.keyboardAppearance = .dark
        textView.indicatorStyle = .white
        textView.layer.cornerRadius = radius
        textView.layer.borderWidth = 1
        textView.layer.borderColor = tint.line.cgColor
        textView.linkTextAttributes = [.foregroundColor: tint.accent]
    }

    // MARK: Table cells and headers

    /// A bordered card background with a tiny corner radius, inset vertically so rows
    /// read as separate cards.
    static func cardConfiguration(tint: Tint = .wallet, highlighted: Bool = false, horizontalInset: CGFloat = 5) -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = highlighted ? tint.accent.withAlphaComponent(0.12) : card
        background.strokeColor = highlighted ? tint.accent : tint.line
        background.strokeWidth = 1
        background.cornerRadius = radius
        // Inset on all sides so the inset-grouped table's rounded section corners (which
        // clip the cell) never reach the card's border.
        background.backgroundInsets = NSDirectionalEdgeInsets(top: 4, leading: horizontalInset, bottom: 4, trailing: horizontalInset)
        return background
    }

    /// Restyles a table cell (storyboard, xib or code) as a card. Call it from
    /// `tableView(_:willDisplay:forRowAt:)` so it runs after the cell is configured.
    static func styleCell(_ cell: UITableViewCell, in tableView: UITableView? = nil, tint: Tint = .wallet) {
        // Full-width cards in grouped / plain tables (the table itself is inset); a small
        // inset inside inset-grouped tables keeps the border clear of the section rounding.
        var table = tableView
        if table == nil {
            var ancestor = cell.superview
            while let current = ancestor, table == nil {
                table = current as? UITableView
                ancestor = current.superview
            }
        }
        let horizontalInset: CGFloat
        if table?.style == .insetGrouped {
            horizontalInset = 5
        } else if let table = table, objc_getAssociatedObject(table, rootTableKey) != nil {
            horizontalInset = 16
        } else {
            horizontalInset = 0
        }
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        cell.automaticallyUpdatesBackgroundConfiguration = false
        cell.backgroundConfiguration = cardConfiguration(tint: tint, horizontalInset: horizontalInset)
        squareCorners(cell)                 // defeat the inset-grouped section rounding
        cell.layer.borderWidth = 0          // the card stroke replaces any old cell border
        cell.tintColor = tint.accent

        if var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.font = mono(from: content.textProperties.font)
            content.textProperties.color = text
            content.secondaryTextProperties.font = mono(from: content.secondaryTextProperties.font)
            content.secondaryTextProperties.color = dim
            content.imageProperties.tintColor = tint.accent
            cell.contentConfiguration = content
        } else {
            cell.contentView.subviews.forEach { style($0, tint: tint) }
        }
        if let accessory = cell.accessoryView { style(accessory, tint: tint) }
    }

    /// Section headers: monospaced accent titles on a clear background.
    static func styleHeader(_ view: UIView, tint: Tint = .wallet) {
        if let header = view as? UITableViewHeaderFooterView {
            var background = UIBackgroundConfiguration.clear()
            background.backgroundColor = .clear
            header.backgroundConfiguration = background
            if var content = header.contentConfiguration as? UIListContentConfiguration {
                content.textProperties.font = mono(12, weight: .semibold)
                content.textProperties.color = tint.accent
                header.contentConfiguration = content
            } else {
                header.textLabel?.font = mono(12, weight: .semibold)
                header.textLabel?.textColor = tint.accent
                header.contentView.subviews.forEach { style($0, tint: tint) }
            }
            return
        }
        view.backgroundColor = .clear
        view.subviews.forEach { sub in
            style(sub, tint: tint)
            if let label = sub as? UILabel {
                label.font = mono(14, weight: .semibold)
                label.textColor = tint.accent
            }
        }
    }
}

/// UILabel with inner padding (badges, pills). Shared by the wallet and home screens.
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
