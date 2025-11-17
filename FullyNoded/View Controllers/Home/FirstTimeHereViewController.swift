//
//  FirstTimeHereViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/17/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class FirstTimeHereViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func visitFullyNoded(_ sender: Any) {
        UIApplication.shared.open(URL(string: "https://fullynoded.app")!, options: [:], completionHandler: nil)
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true)
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
