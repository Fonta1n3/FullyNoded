//
//  InvoiceSettingsViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 4/30/23.
//  Copyright © 2023 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class InvoiceSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        table.layer.cornerRadius = 8
        table.clipsToBounds = true
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "invoiceCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        let chevron = cell.viewWithTag(3) as! UIImageView
        label.text = "Bitcoin Core Wallets"
        label.textColor = .label
        chevron.alpha = 1
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToBitcoinCoreWallets", sender: vc)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        textLabel.text = "Bitcoin Core Wallets"
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
}
