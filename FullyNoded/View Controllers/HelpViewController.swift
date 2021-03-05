//
//  HelpViewController.swift
//  BitSense
//
//  Created by Peter on 20/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    
    var labelText = ""
    var textViewText = ""
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = labelText
        textView.text = textViewText
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
    }
    
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true, completion: nil)
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
