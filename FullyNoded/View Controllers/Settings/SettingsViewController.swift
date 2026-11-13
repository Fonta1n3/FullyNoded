//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import Foundation

/// Settings home, built in code. The storyboard scene is only the tab's root shell: it
/// keeps the navigation-controller relationship and the Security / Currency / App Icon
/// segues. Node Manager is pushed in code.
class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private enum Row {
        case nodes, security, currency, appIcon
    }

    private let sections: [(title: String, rows: [Row])] = [
        ("> NODES", [.nodes]),
        ("> SECURITY", [.security]),
        ("> DISPLAY", [.currency, .appIcon])
    ]

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var nodeCount = 0
    private var activeNodeLabel: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // navigationItem only: `title` would also put "Settings" under the tab bar icon.
        navigationItem.title = "Settings"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionFooterHeight = 0
        tableView.register(ThemedRowCell.self, forCellReuseIdentifier: ThemedRowCell.reuseId)
        tableView.tableFooterView = versionFooter()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .settings)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadNodeSummary()
    }

    /// Node count and the active node's label, for the Node Manager row.
    private func loadNodeSummary() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            let structs = (nodes ?? []).map { NodeStruct(dictionary: $0) }.filter { $0.id != nil }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.nodeCount = structs.count
                self.activeNodeLabel = structs.first(where: { $0.isActive })?.label
                self.tableView.reloadData()
            }
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "FULLY NODED v\(version) (\(build))"
    }

    private func versionFooter() -> UIView {
        let label = UILabel()
        label.text = Self.versionText
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 56)
        label.autoresizingMask = [.flexibleWidth]
        return label
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThemedRowCell.reuseId, for: indexPath) as! ThemedRowCell

        switch sections[indexPath.section].rows[indexPath.row] {
        case .nodes:
            let subtitle: String
            if nodeCount == 0 {
                subtitle = "No nodes yet, tap to add one"
            } else if let active = activeNodeLabel, !active.isEmpty {
                subtitle = "Active: \(active) · \(nodeCount) node\(nodeCount == 1 ? "" : "s")"
            } else {
                subtitle = "\(nodeCount) node\(nodeCount == 1 ? "" : "s"), none active"
            }
            cell.configure(icon: "server.rack", title: "Node Manager", subtitle: subtitle)

        case .security:
            let locked = KeyChain.getData("UnlockPassword") != nil
            cell.configure(icon: "lock.shield",
                           title: "Security Center",
                           subtitle: locked ? "App lock on" : "No app lock set",
                           value: locked ? nil : "!",
                           valueIsWarning: !locked)

        case .currency:
            let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
            let symbol = Currencies.currenciesWithCircle.compactMap { $0[currency] }.first ?? "dollarsign.circle"
            cell.configure(icon: symbol, title: "Fiat currency", subtitle: "Balances and amounts", value: currency)

        case .appIcon:
            cell.configure(icon: "app.badge", title: "App icon", subtitle: "Home screen icon")
        }

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let caption = WalletTheme.caption(sections[section].title, tint: .settings)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 2),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 36 : 44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        impact()

        switch sections[indexPath.section].rows[indexPath.row] {
        case .nodes:
            navigationController?.pushViewController(NodesViewController(), animated: true)
        case .security:
            performSegue(withIdentifier: "goToSecurity", sender: self)
        case .currency:
            performSegue(withIdentifier: "segueToCurrencies", sender: self)
        case .appIcon:
            performSegue(withIdentifier: "segueToAppIconSelector", sender: self)
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .settings)
    }
}

// MARK: - Row cell

/// Settings-style row: bordered icon tile, title, subtitle, optional value / badge,
/// and a chevron or an action button. Used by Settings, the Node Manager and Signers.
final class ThemedRowCell: UITableViewCell {
    static let reuseId = "ThemedRowCell"

    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    /// Optional trailing action (hidden unless `configure` gets one).
    let actionButton = UIButton(type: .system)

    private var tint: WalletTheme.Tint = .settings

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        iconTile.layer.borderWidth = 1
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconView)

        titleLabel.font = WalletTheme.mono(15, weight: .semibold)
        titleLabel.numberOfLines = 1
        subtitleLabel.font = WalletTheme.mono(11)
        subtitleLabel.numberOfLines = 2
        valueLabel.font = WalletTheme.mono(13, weight: .bold)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isHidden = true

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = 3

        let row = UIStackView(arrangedSubviews: [iconTile, texts, valueLabel, actionButton, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        let bottom = row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        bottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottom,
            iconTile.widthAnchor.constraint(equalToConstant: 36),
            iconTile.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 36),
            actionButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        actionButton.removeTarget(nil, action: nil, for: .allEvents)
    }

    /// - value: short trailing text (e.g. "USD", "ACTIVE"); `valueIsWarning` shows it in red.
    /// - dimmed: inactive look (dim title and icon).
    /// - action: trailing icon button instead of the chevron.
    func configure(icon: String,
                   title: String,
                   subtitle: String?,
                   value: String? = nil,
                   valueIsWarning: Bool = false,
                   dimmed: Bool = false,
                   tint: WalletTheme.Tint = .settings,
                   action: (symbol: String, target: Any, selector: Selector, tag: Int)? = nil) {
        self.tint = tint
        let accent = dimmed ? tint.dim : tint.accent

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = accent
        iconTile.layer.borderColor = (dimmed ? tint.dim.withAlphaComponent(0.4) : tint.line).cgColor
        iconTile.backgroundColor = .clear

        titleLabel.text = title
        titleLabel.textColor = dimmed ? tint.dim : tint.text
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle ?? "").isEmpty
        subtitleLabel.textColor = tint.dim

        valueLabel.text = value
        valueLabel.isHidden = (value ?? "").isEmpty
        valueLabel.textColor = valueIsWarning ? WalletTheme.danger : tint.accent

        if let action = action {
            actionButton.isHidden = false
            chevron.isHidden = true
            actionButton.tag = action.tag
            actionButton.setImage(UIImage(systemName: action.symbol,
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                                  for: .normal)
            actionButton.tintColor = tint.accent
            actionButton.addTarget(action.target, action: action.selector, for: .touchUpInside)
        } else {
            actionButton.isHidden = true
            chevron.isHidden = false
            chevron.tintColor = tint.dim
        }
    }
}
