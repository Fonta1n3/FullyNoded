//
//  TimeLockView.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/5/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import UIKit

// Define the type of data you want to pass back
typealias TimelockCompletion = (UInt32, String, String) -> Void
// (timestamp: UInt64, afterFragment: String) e.g. (1798761600, "after(1798761600)")

final class TimelockViewController: UIViewController {
    
    // MARK: - Public Properties
    
    /// Completion handler called when user confirms selection
    var completion: TimelockCompletion?
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Timelock Date"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a future date (timestamp mode)"
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Date() // Only future dates
        picker.maximumDate = Calendar.current.date(from: DateComponents(year: 2105, month: 12, day: 31)) // Limit prior to the bitcoin killer bug.
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = .secondarySystemBackground
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.text = "Select a date →"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var doneButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }()
    
    private lazy var doneActionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Confirm Timelock"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.title = "Select Timelock Date"
           
           // Important for sheet presentation
           if #available(iOS 15.0, *) {
               // Ensures content extends under the grabber
               view.insetsLayoutMarginsFromSafeArea = false
           }
           
           setupUI()
           updateTimestamp(for: datePicker.date)
           datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(instructionLabel)
        view.addSubview(datePicker)
        view.addSubview(timestampLabel)
        view.addSubview(doneActionButton) // Add this
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            datePicker.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 40),
            datePicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timestampLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 50),
            timestampLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            timestampLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            timestampLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // New: Done button at bottom
            doneActionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            doneActionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            doneActionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            doneActionButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func dateChanged() {
        updateTimestamp(for: datePicker.date)
    }
    
    @objc private func doneTapped() {
        let selectedDate = datePicker.date
        let timestamp = UInt32(selectedDate.timeIntervalSince1970)
        let afterFragment = "after(\(timestamp))"
        
        // Call the completion handler
        completion?(timestamp, afterFragment, selectedDate.dateDisplay)
        
        // Dismiss the view controller
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Helpers
    
    private func updateTimestamp(for date: Date) {
        let timestamp = UInt64(date.timeIntervalSince1970)
        
        timestampLabel.text = """
        Timestamp:
        \(timestamp)
        
        Miniscript fragment:
        after(\(timestamp))
        
        Selected: \(date.dateDisplay)
        """
    }
    
    
}

extension Date {
    var dateDisplay: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return "\(dateFormatter.string(from: self))"
    }
}
