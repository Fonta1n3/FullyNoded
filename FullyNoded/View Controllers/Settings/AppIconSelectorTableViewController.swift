//
//  AppIconSelectorTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/15/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class AppIconSelectorTableViewController: UITableViewController {
    
    var currentIcon: String? = nil

    var appIcons: [[String?: UIImage]] = [
        ["AppIcon-6": UIImage(named: "Default_Icon")!],
        [nil: UIImage(named: "Original_Icon")!]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        currentIconName { [weak self] name in
            guard let self = self else { return }
            
            guard let name = name else {
                return
            }
            
            self.currentIcon = name
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return appIcons.count
    }

    // MARK: - Get Current Icon (FIXED)
    func currentIconName(completion: @escaping (String?) -> Void) {
        let current = UIApplication.shared.alternateIconName
        DispatchQueue.main.async {
            completion(current)
        }
    }

    // MARK: - Set Icon
    func setIcon(name: String?, completion: ((Bool, Error?) -> Void)? = nil) {
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(false, error)
                } else {
                    completion?(true, nil)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "appIconCell", for: indexPath)
        cell.selectionStyle = .none
        let icon = cell.viewWithTag(1) as! UIImageView
        icon.layer.cornerRadius = 8
        icon.clipsToBounds = true
        let appIcon = appIcons[indexPath.row]
        
        for (key, value) in appIcon {
            icon.image = value
            
            if key == currentIcon {
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
        let appIcon = appIcons[indexPath.row]
        for (key, _) in appIcon {
            setIcon(name: key) { [weak self] success, error in
                guard let self = self else { return }
                
                if success {
                    currentIcon = key
                    
                    DispatchQueue.main.async {
                        tableView.reloadData()
                    }
                } else {
                    showAlert(vc: self, title: "", message: error?.localizedDescription ?? "Unable to set app icon. Only works on mobile devices.")
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }

}
