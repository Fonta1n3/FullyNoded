//
//  TextModalViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/7/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class TextModalViewController: UIViewController {
    
    private let data: [String: Any]
    private let viewTitle: String
    private var prettyText: String = ""
    
    init(data: [String: Any], viewTitle: String) {
        self.data = data
        self.viewTitle = viewTitle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var codeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont(name: "Menlo", size: 14) ?? UIFont.preferredFont(forTextStyle: .body) // Monospaced for alignment
        label.textColor = .systemGreen
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewTitle
        
        setupUI()
        setupNavigationButtons()
        
        textLabel.text = prettyPrintedJSON(from: data)
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(codeContainer)
        codeContainer.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            codeContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            codeContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            codeContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            codeContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            
            codeContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
            
            codeContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 800).withPriority(.defaultHigh),
            
            textLabel.topAnchor.constraint(equalTo: codeContainer.topAnchor, constant: 24),
            textLabel.leadingAnchor.constraint(equalTo: codeContainer.leadingAnchor, constant: 24),
            textLabel.trailingAnchor.constraint(equalTo: codeContainer.trailingAnchor, constant: -24),
            textLabel.bottomAnchor.constraint(equalTo: codeContainer.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupNavigationButtons() {
        let copyButton = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(copyToClipboard)
        )
        copyButton.tintColor = .systemBlue
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                         target: self,
                                         action: #selector(dismissModal))
        
        navigationItem.leftBarButtonItem = copyButton
        navigationItem.rightBarButtonItem = doneButton
    }
    
    @objc private func copyToClipboard() {
        UIPasteboard.general.string = prettyText
        
        let alert = UIAlertController(title: "Copied!", message: "Pretty-printed data copied to clipboard.", preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true)
    }
    
    // MARK: Pretty-Print Logic
    private func prettyPrintedJSON(from dictionary: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            var jsonString = String(data: jsonData, encoding: .utf8) ?? "Unable to format data."
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
            
            return jsonString
        } catch {
            return "Error formatting data: \(error.localizedDescription)\n\nRaw: \(dictionary)"
        }
    }
}

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
