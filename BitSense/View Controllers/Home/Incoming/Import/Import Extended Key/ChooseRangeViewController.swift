//
//  ChooseRangeViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ChooseRangeViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    let picker = UIPickerView()
    
    var range = ""
    var dict = [String:Any]()
    
    let ud = UserDefaults.standard

    override func viewDidLoad() {
        super.viewDidLoad()

        configurePicker()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        addPicker()
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "addToKeypool", sender: self)
            
        }
        
    }
    
    func configurePicker() {
        
        picker.dataSource = self
        picker.delegate = self
        picker.isUserInteractionEnabled = true
        
        let frame = view.frame
        
        picker.frame = CGRect(x: 0,
                              y: 250,
                              width: frame.width,
                              height: 200)
        
        picker.backgroundColor = self.view.backgroundColor
        
    }
    
    func addPicker() {
        
        view.addSubview(picker)
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 1000
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        let string = "\(row * 100) to \(row * 100 + 199)"
        return NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let row = pickerView.selectedRow(inComponent: component)
        let string = "\(row * 100) to \(row * 100 + 199)"
        self.range = string
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "addToKeypool":
            
            if let vc = segue.destination as? AddToKeypoolViewController  {
                
                if range == "" {
                    
                    range = "0 to 199"
                    
                }
                
                dict["range"] = range
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
    }

}
