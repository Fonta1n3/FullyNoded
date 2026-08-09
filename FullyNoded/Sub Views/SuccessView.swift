//
//  SuccessView.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/6/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import UIKit

final class SuccessView: UIView {
    
    // MARK: - Public Properties
    
    /// Called when the user taps "Done" and the view finishes dismissing
    var onDismiss: (() -> Void)?
    
    // MARK: - Private UI Elements
    
    private let overlayView = UIView()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        return view
    }()
    
    private let checkmarkImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        let image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.tintColor = .systemGreen
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var doneButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Done"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .boldSystemFont(ofSize: 15)
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Init
    
    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        self.titleLabel.text = title
        self.subtitleLabel.text = subtitle
        setupView()
        animateIn()
        triggerHaptic()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(cardView)
        
        [checkmarkImageView, titleLabel, subtitleLabel, doneButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            checkmarkImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            checkmarkImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 120),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            doneButton.topAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.bottomAnchor, constant: 30),
            doneButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            doneButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            doneButton.heightAnchor.constraint(equalToConstant: 56),
            doneButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func doneButtonTapped() {
        animateOut()
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        cardView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        cardView.alpha = 0
        checkmarkImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5,
                       options: []) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
            self.checkmarkImageView.transform = .identity
        }
        
        // Pulse effect on checkmark
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.15
        pulse.duration = 0.4
        pulse.autoreverses = true
        checkmarkImageView.layer.add(pulse, forKey: "pulse")
    }
    
    private func animateOut() {
        UIView.animate(withDuration: 0.4, animations: {
            self.overlayView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }
    
    // MARK: - Helpers
    
    private func triggerHaptic() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
}

// MARK: - Convenience Static Show Method

extension SuccessView {
    
    /// Shows the success view with a "Done" button. User must tap to dismiss.
    static func show(in viewController: UIViewController,
                     title: String,
                     subtitle: String = "",
                     onDismiss: (() -> Void)? = nil) {
        
        let successView = SuccessView(title: title, subtitle: subtitle)
        successView.onDismiss = onDismiss
        
        viewController.view.addSubview(successView)
        successView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            successView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            successView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            successView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            successView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }
}
