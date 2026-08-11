//
//  BackupWarningView.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/6/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import UIKit

/// A full-screen urgent warning that forces the user to tap "Got It" to dismiss.
/// Perfect for critical actions like "your wallet backup is now outdated".
final class BackupWarningView: UIView {
    
    // MARK: - Properties
    
    private var completion: (() -> Void)?
    
    private let blurEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        return UIVisualEffectView(effect: blur)
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0) }
        view.layer.cornerRadius = 28
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private let warningIcon: UILabel = {
        let label = UILabel()
        label.text = "⚠️"
        label.font = UIFont.systemFont(ofSize: 80)
        label.textAlignment = .center
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Backup Required Immediately"
        label.font = UIFont.boldSystemFont(ofSize: 26)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "A new timelocked descriptor has been added to your wallet.\n\n"
                   + "Your physical backup no longer includes these funds.\n\n"
                   + "If you lose access and only have an old backup, these funds will be permanently lost.\n\n"
                   + "Please update your physical wallet backup now."
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var gotItButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Got It"
        config.baseBackgroundColor = .systemOrange
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        
        let button = UIButton(configuration: config)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        
        addSubview(blurEffectView)
        addSubview(cardView)
        
        let stack = UIStackView(arrangedSubviews: [
            warningIcon,
            titleLabel,
            messageLabel,
            gotItButton
        ])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        
        cardView.addSubview(stack)
        
        // Constraints
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.heightAnchor, multiplier: 0.65),
            
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 60),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -60),
            
            gotItButton.heightAnchor.constraint(equalToConstant: 56),
            gotItButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 20),
            gotItButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func dismissTapped() {
        dismiss(animated: true) { [weak self] in
            self?.completion?()
        }
    }
    
    private func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: 0.6,
                           delay: 0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.8,
                           options: .curveEaseIn) {
                self.backgroundColor = .clear
                self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.frame.height + 100)
            } completion: { _ in
                self.removeFromSuperview()
                completion?()
            }
        } else {
            removeFromSuperview()
            completion?()
        }
    }
    
    // MARK: - Public Show Method
    
    /// Shows the warning over the full app window (works on iPhone, iPad, and Mac Catalyst)
    static func show(completion: (() -> Void)? = nil) {
        let warning = BackupWarningView()
        warning.completion = completion
        
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .windows
                .first(where: { $0.isKeyWindow }) else {
            return
        }
        
        window.addSubview(warning)
        warning.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            warning.topAnchor.constraint(equalTo: window.topAnchor),
            warning.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            warning.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            warning.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        
        // Start off-screen
        warning.cardView.transform = CGAffineTransform(translationX: 0, y: warning.cardView.frame.height + 100)
        warning.backgroundColor = .clear
        
        // Animate in
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.7,
                       options: .curveEaseOut) {
            warning.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            warning.cardView.transform = .identity
        }
    }
}
