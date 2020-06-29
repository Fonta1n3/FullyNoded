//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateFullyNodedWalletViewController: UIViewController {
    
    @IBOutlet weak var singleSigOutlet: UIButton!
    @IBOutlet weak var recoveryOutlet: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        singleSigOutlet.layer.cornerRadius = 8
        recoveryOutlet.layer.cornerRadius = 8
    }
    
    @IBAction func automaticAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSeedWords", sender: vc)
        }
    }
    
    @IBAction func manualAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "seguToManualCreation", sender: vc)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
