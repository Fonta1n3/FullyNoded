//
//  WalletExportFormatView.swift
//  FullyNoded
//
//  Created by F on 1/7/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import UIKit

enum WalletExportFormat: Int {
    case qr = 1
    case file = 2
    case text = 3
}

/// A clean, reusable full-screen prompt to choose wallet backup export format
final class WalletExportFormatView: UIView {
    
    // MARK: - Callback
    
    var onSelection: ((WalletExportFormat?) -> Void)?
    
    // MARK: - UI Components
    
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Export Wallet Backup"
        label.font = .boldSystemFont(ofSize: 26)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your preferred format"
        label.font = .systemFont(ofSize: 17)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Init
    
    init() {
        super.init(frame: .zero)
        setupView()
        setupActions()
        animateIn()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        addSubview(overlayView)
        overlayView.addSubview(cardView)
        
        // Add all content
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(closeButton)
        
        // Create option buttons
        let qrOption = makeOptionButton(
            title: "QR Code",
            subtitle: "Scan with another device",
            iconName: "qrcode.viewfinder",
            format: .qr
        )

        let fileOption = makeOptionButton(
            title: "Save as File",
            subtitle: "Hex-encoded backup",
            iconName: "square.and.arrow.up",
            format: .file
        )

        let textOption = makeOptionButton(
            title: "Copy as Text",
            subtitle: "Hex-encoded backup",
            iconName: "doc.text",
            format: .text
        )

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, qrOption, fileOption, textOption])
        stack.axis = .vertical
        stack.spacing = 22
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        
        // Constraints
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            
            closeButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            stack.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }
    
    private func makeOptionButton(title: String, subtitle: String, iconName: String, format: WalletExportFormat) -> UIView {
        // Container view for the entire tappable area
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textColor = .label
        
        // Subtitle label
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        
        // Stack for labels
        let labelsStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 4
        labelsStack.alignment = .leading
        
        // Horizontal stack: icon + labels
        let contentStack = UIStackView(arrangedSubviews: [iconImageView, labelsStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 16
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),
            
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            
            container.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        // Add tap gesture — same reliable method as close button
        let tap = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        
        // Store the format using associated object or tag
        container.tag = format.rawValue  // We'll define rawValue below
        
        // Visual feedback on tap
        tap.addTarget(self, action: #selector(buttonTouchDown(_:)))
        
        return container
    }

    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let format = WalletExportFormat(rawValue: view.tag)!
        dismiss(with: format)
    }

    @objc private func buttonTouchDown(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        UIView.animate(withDuration: 0.15) {
            view.alpha = 0.7
        }
    }

    @objc private func buttonTouchUp(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        UIView.animate(withDuration: 0.15) {
            view.alpha = 1.0
        }
    }
    
    private func setupActions() {
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(with: nil)
        }, for: .touchUpInside)
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        cardView.alpha = 0
        
        UIView.animate(withDuration: 0.55,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.6,
                       options: .curveEaseOut) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.cardView.alpha = 0
            self.overlayView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion()
        }
    }
    
    // MARK: - Dismiss
    
    private func dismiss(with format: WalletExportFormat?) {
        animateOut { [weak self] in
            self?.onSelection?(format)
        }
    }
}

// MARK: - Static Show Extension

extension WalletExportFormatView {
    
    static func show(in viewController: UIViewController,
                     onSelection: @escaping (WalletExportFormat?) -> Void) {
        
        let exportView = WalletExportFormatView()
        exportView.onSelection = onSelection
        
        viewController.view.addSubview(exportView)
        
        exportView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            exportView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            exportView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            exportView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            exportView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }
}
