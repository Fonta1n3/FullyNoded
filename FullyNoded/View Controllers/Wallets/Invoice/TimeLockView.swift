//
//  TimeLockView.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/5/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//
//  The date picker for a timelocked receive address (a sheet over the Receive screen): quick
//  presets, a calendar, the unlock date with a countdown, the miniscript it becomes, and what a
//  lock means before confirming.
//

import UIKit

/// (timestamp, afterFragment, displayDate), e.g. (1798761600, "after(1798761600)", "Dec 31, 2026 at …")
typealias TimelockCompletion = (UInt32, String, String) -> Void

final class TimelockViewController: UIViewController {

    /// Called with the chosen date when the user confirms.
    var completion: TimelockCompletion?
    /// Preselected date (from a preset on the Receive screen).
    var initialDate: Date?

    private let tint: WalletTheme.Tint = .warning

    /// At least a day ahead: "today" gives a lock that has already expired (and the node compares
    /// against median time past, about an hour behind the clock).
    static var earliest: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }
    /// Miniscript's after() only accepts values below 2^31, so Jan 19, 2038 is the latest date that
    /// makes a valid descriptor (anything later fails with a confusing parse error).
    static let latest = Date(timeIntervalSince1970: 2_147_483_647)

    /// Quick picks, shared with the Receive screen's timelock card.
    static let presets: [(title: String, component: Calendar.Component, value: Int)] = [
        ("1 month", .month, 1), ("6 months", .month, 6), ("1 year", .year, 1), ("4 years", .year, 4)
    ]

    static func date(for preset: (title: String, component: Calendar.Component, value: Int)) -> Date {
        let date = Calendar.current.date(byAdding: preset.component, value: preset.value, to: Date()) ?? earliest
        return min(max(date, earliest), latest)
    }

    /// "1 year, 2 months" until `date`.
    static func countdown(to date: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .day]
        formatter.maximumUnitCount = 2
        return formatter.string(from: Date(), to: date) ?? ""
    }

    private let scrollView = UIScrollView()
    private let datePicker = UIDatePicker()
    private let dateLabel = UILabel()
    private let countdownLabel = UILabel()
    private let detailsLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private var presetButtons: [UIButton] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        WalletTheme.apply(to: self, tint: .receive)
        view.backgroundColor = WalletTheme.bg
        overrideUserInterfaceStyle = .dark
        buildLayout()
        datePicker.date = min(max(initialDate ?? Self.date(for: Self.presets[2]), Self.earliest), Self.latest)
        update()
    }

    // MARK: Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)), for: .normal)
        close.tintColor = WalletTheme.dim
        close.accessibilityLabel = "Cancel"
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        let title = UILabel()
        title.text = "Timelock"
        title.font = WalletTheme.mono(20, weight: .bold)
        title.textColor = WalletTheme.text
        let titleRow = UIStackView(arrangedSubviews: [title, UIView(), close])
        titleRow.alignment = .center

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(summaryCard())
        stack.addArrangedSubview(pickerCard())
        stack.addArrangedSubview(warningCard())

        WalletTheme.styleHero(confirmButton, title: "Lock until…", systemImage: "lock.fill", tint: tint)
        confirmButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        stack.addArrangedSubview(confirmButton)
    }

    private func summaryCard() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "hourglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)))
        icon.tintColor = tint.accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        dateLabel.font = WalletTheme.mono(19, weight: .bold)
        dateLabel.textColor = tint.accent
        dateLabel.numberOfLines = 0
        dateLabel.adjustsFontSizeToFitWidth = true
        dateLabel.minimumScaleFactor = 0.7
        countdownLabel.font = WalletTheme.mono(12, weight: .semibold)
        countdownLabel.textColor = WalletTheme.text
        countdownLabel.numberOfLines = 0
        let texts = UIStackView(arrangedSubviews: [dateLabel, countdownLabel])
        texts.axis = .vertical
        texts.spacing = 4
        let row = UIStackView(arrangedSubviews: [icon, texts])
        row.spacing = 12
        row.alignment = .center

        detailsLabel.font = WalletTheme.mono(10)
        detailsLabel.textColor = WalletTheme.dim
        detailsLabel.numberOfLines = 0
        let card = WalletTheme.cardView([WalletTheme.caption("> UNLOCKS", tint: tint), row, detailsLabel],
                                        tint: tint, spacing: 10, background: tint.accent.withAlphaComponent(0.06))
        card.layer.borderColor = tint.accent.cgColor
        return card
    }

    private func pickerCard() -> UIView {
        presetButtons = Self.presets.enumerated().map { index, preset in
            let button = UIButton(type: .system)
            button.tag = index
            button.configuration = WalletTheme.chipConfiguration(title: preset.title, tint: tint, fontSize: 11, imageSize: 10, imagePadding: 0,
                                                                 insets: NSDirectionalEdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6),
                                                                 clipsTitle: true)
            button.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            return button
        }
        let presets = UIStackView(arrangedSubviews: presetButtons)
        presets.spacing = 6
        presets.distribution = .fillEqually

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.minimumDate = Self.earliest
        datePicker.maximumDate = Self.latest
        datePicker.tintColor = tint.accent
        datePicker.overrideUserInterfaceStyle = .dark
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        return WalletTheme.cardView([WalletTheme.caption("> CHOOSE A DATE", tint: tint), presets, datePicker], tint: tint, spacing: 12)
    }

    private func warningCard() -> UIView {
        let rows: [(String, String)] = [
            ("lock.fill", "Coins sent to the timelocked address can't be spent before this date, not even by you."),
            ("key.fill", "The lock uses the same key as the address you were shown, so that key also appears on that address (reusing a key links the two on-chain)."),
            ("externaldrive.fill", "The timelocked address is added to your wallet backup: export a fresh one afterwards.")
        ]
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 10
        for (symbol, text) in rows {
            let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
            icon.tintColor = tint.accent
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
            let label = UILabel()
            label.text = text
            label.font = WalletTheme.mono(11)
            label.textColor = WalletTheme.text
            label.numberOfLines = 0
            let row = UIStackView(arrangedSubviews: [icon, label])
            row.spacing = 8
            row.alignment = .firstBaseline
            list.addArrangedSubview(row)
        }
        return WalletTheme.cardView([WalletTheme.caption("> BEFORE YOU LOCK", tint: tint), list], tint: tint, spacing: 10)
    }

    // MARK: Actions

    @objc private func presetTapped(_ sender: UIButton) {
        datePicker.setDate(Self.date(for: Self.presets[sender.tag]), animated: true)
        UISelectionFeedbackGenerator().selectionChanged()
        update()
    }

    @objc private func dateChanged() {
        update()
    }

    @objc private func doneTapped() {
        let selectedDate = datePicker.date
        let timestamp = UInt32(min(selectedDate.timeIntervalSince1970, Self.latest.timeIntervalSince1970))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        completion?(timestamp, "after(\(timestamp))", selectedDate.dateDisplay)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    // MARK: Display

    private func update() {
        let date = datePicker.date
        let timestamp = UInt32(min(date.timeIntervalSince1970, Self.latest.timeIntervalSince1970))
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        dateLabel.text = formatter.string(from: date)
        countdownLabel.text = "in \(Self.countdown(to: date))"
        detailsLabel.text = "Unix time \(timestamp) · miniscript after(\(timestamp)). Checked against the chain's median time, about an hour behind the clock."

        let short = DateFormatter()
        short.dateStyle = .medium
        short.timeStyle = .none
        WalletTheme.styleHero(confirmButton, title: "Lock until \(short.string(from: date))", systemImage: "lock.fill", tint: tint)

        let calendar = Calendar.current
        for (index, button) in presetButtons.enumerated() {
            let selected = calendar.isDate(Self.date(for: Self.presets[index]), inSameDayAs: date)
            button.configuration?.background.backgroundColor = selected ? tint.accent : WalletTheme.card
            button.configuration?.baseForegroundColor = selected ? WalletTheme.bg : tint.accent
        }
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
