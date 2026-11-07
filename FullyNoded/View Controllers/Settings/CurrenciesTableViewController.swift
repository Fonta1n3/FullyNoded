//
//  CurrenciesTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/16/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class CurrenciesTableViewController: UITableViewController {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    let currencies = Currencies.currenciesWithCircle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Fiat Currency"
        tableView.rowHeight = 54
        tableView.register(CurrencyCell.self, forCellReuseIdentifier: "currenciesCell")
        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .settings)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currencies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "currenciesCell", for: indexPath)
        cell.selectionStyle = .none
        guard let cell = cell as? CurrencyCell else { return cell }
        let label = cell.label
        let icon = cell.icon
        let currencyDict = currencies[indexPath.row]
        let existingCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        for (key, value) in currencyDict {
            label.text = key
            icon.image = UIImage(systemName: value)
            
            if key == existingCurrency {
                cell.isSelected = true
                cell.accessoryType = .checkmark
            } else {
                cell.isSelected = false
                cell.accessoryType = .none
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currencyDict = currencies[indexPath.row]
        
        for key in currencyDict.keys {
            UserDefaults.standard.set(key, forKey: "currency")
            updateFxRate(currency: key)
        }
    }
    
    func updateFxRate(currency: String) {
        showActivity("fetching fx rate...")
        
        FiatConverter.sharedInstance.getFxRate(currency: currency) { [weak self] fxRate in
            guard let self = self else { return }
            
            hideActivity()
            
            guard let fxRate = fxRate else {
                showAlert(vc: self, title: "", message: "There was an error fetching the exchange rate for \(currency).")
                return
            }
            
            UserDefaults.standard.setValue(fxRate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                tableView.reloadData()
                
                showAlert(vc: self, title: "", message: "You need to tap the refresh button on the active wallet view to update the balance currency.")
            }
        }
    }

    // MARK: - Theme

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .settings)
    }
}

/// Currency symbol and code.
private final class CurrencyCell: UITableViewCell {
    let icon = UIImageView()
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        for subview in [icon, label] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 25),
            icon.heightAnchor.constraint(equalToConstant: 25),
            icon.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
