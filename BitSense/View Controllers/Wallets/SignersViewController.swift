//
//  SignersViewController.swift
//  BitSense
//
//  Created by Peter on 04/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var signerTable: UITableView!
    var signers = [[String:Any]]()
    var id:UUID!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addSignerSegue", sender: vc)
        }
    }
    
    
    private func loadData() {
        signers.removeAll()
        CoreDataService.retrieveEntity(entityName: .signers) { [unowned vc = self] encryptedSigners in
            if encryptedSigners != nil {
                if encryptedSigners!.count > 0 {
                    vc.signers = encryptedSigners!
                    vc.reload()
                }
            } else {
                vc.reload()
            }
        }
    }
    
    private func reload() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.signerTable.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return signers.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        let button = cell.viewWithTag(2) as! UIButton
        let image = cell.viewWithTag(3) as! UIImageView
        let background = cell.viewWithTag(4)!
        background.clipsToBounds = true
        let icon = UIImage(systemName: "square.and.pencil")
        background.backgroundColor = .darkGray
        background.layer.cornerRadius = 5
        image.tintColor = .white
        image.image = icon
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(seeDetails(_:)), for: .touchUpInside)
        if signers.count > 0 {
            let s = SignerStruct(dictionary: signers[indexPath.section])
            if s.label == "Signer" {
                label.text = "Signer #\(indexPath.section + 1)"
            } else {
                label.text = s.label
            }
        }
        return cell
    }
    
    @objc func seeDetails(_ sender: UIButton) {
        if sender.restorationIdentifier != nil {
            if let int = Int(sender.restorationIdentifier!) {
                id = SignerStruct(dictionary: signers[int]).id
                segueToDetail()
            }
        }
    }
    
    private func segueToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSignerDetail", sender: vc)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToSignerDetail" {
            if let vc = segue.destination as? SignerDetailViewController {
                vc.id = id
            }
        }
    }

}
