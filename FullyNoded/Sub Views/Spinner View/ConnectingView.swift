//
//  ConnectingView.swift
//  BitSense
//
//  Created by Peter on 06/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

/// A singleton overlay view that shows a blurred background with a large activity indicator and description label.
/// Designed to be shown over any view controller safely and removed cleanly.
import UIKit

final class ConnectingView {
    
    static let shared = ConnectingView()
    
    private init() {}
    
    // MARK: - Private Views
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    let label = UILabel()
    
    private var isVisible = false
    
    // MARK: - Public Methods
    
    func show(vc: UIViewController, description: String = "") {
        guard !isVisible else {
            return
        }
        isVisible = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupViews(in: vc, description: description)
            self.animateIn()
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        guard isVisible else {
            completion?()
            return
        }
        isVisible = false
        
        DispatchQueue.main.async { [weak self] in
            self?.animateOut(completion: completion)
        }
    }
        
    private func setupViews(in viewController: UIViewController, description: String) {
        blurView.removeFromSuperview()
        blurView.translatesAutoresizingMaskIntoConstraints = false
        
        viewController.view.addSubview(blurView)
        
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        // Label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = description
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        blurView.contentView.addSubview(activityIndicator)
        blurView.contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: blurView.centerYAnchor, constant: -40),
            
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -40),
        ])
    }
    
    private func animateIn() {
        blurView.alpha = 0
        activityIndicator.alpha = 0
        label.alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.blurView.alpha = 1
            self.activityIndicator.alpha = 1
            self.label.alpha = 1
        }
    }
    
    private func animateOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.blurView.alpha = 0
            self.activityIndicator.alpha = 0
            self.label.alpha = 0
        }) { _ in
            self.blurView.removeFromSuperview()
            self.activityIndicator.stopAnimating()
            completion?()
        }
    }
}


