//
//  DynamicFooterView.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/6/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class DynamicFooterView: UIView {
    let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0 // Allow multiple lines
        label.font = UIFont.systemFont(ofSize: 15) // Adjust font as needed
        label.textColor = .tertiaryLabel
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(textLabel)
        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10), // Add padding
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10) // Add padding
        ])
    }
    
    func configure(with text: String) {
        textLabel.text = text
    }
}
