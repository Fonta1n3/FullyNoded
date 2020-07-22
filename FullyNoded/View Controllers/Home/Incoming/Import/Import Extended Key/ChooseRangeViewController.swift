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
    let connectingView = ConnectingView()
    var range = ""
    var dict = [String:Any]()
    var isHDMusig = Bool()
    var keyArray = NSArray()
    var isDescriptor = Bool()
    
    let ud = UserDefaults.standard

    override func viewDidLoad() {
        super.viewDidLoad()

        configurePicker()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        addPicker()
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        if isHDMusig {
            
            getHDMusigAddresses()
            
        } else {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "addToKeypool", sender: self)
                
            }
            
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
        
        let string = "\(row * 2000) to \(row * 2000 + 2000)"
        return NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let row = pickerView.selectedRow(inComponent: component)
        let string = "\(row * 2000) to \(row * 2000 + 2000)"
        self.range = string
        
    }
    
    func convertRange() -> [Int] {
        
        if range == "" {
            
            range = "0 to 2000"
            
        }
        
        var arrayToReturn = [Int]()
        let newrange = range.replacingOccurrences(of: " ", with: "")
        let rangeArray = newrange.components(separatedBy: "to")
        let zero = Int(rangeArray[0])!
        let one = Int(rangeArray[1])!
        arrayToReturn = [zero,one]
        dict["convertedRange"] = arrayToReturn
        return arrayToReturn
        
    }
    
    func getHDMusigAddresses() {
        connectingView.addConnectingView(vc: self, description: "deriving HD multisig addresses")
        let convertedRange = convertRange()
        let descriptor = dict["descriptor"] as! String
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\(descriptor)") { [unowned vc = self] (response, errorMessage) in
            if let result = response as? NSDictionary {
                let descriptor = "\"\(result["descriptor"] as! String)\""
                vc.deriveAddresses(param: "\(descriptor), ''\(convertedRange)''")
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
            }
        }
    }
    
    private func deriveAddresses(param: String) {
        Reducer.makeCommand(command: .deriveaddresses, param: param) { (response, errorMessage) in
            if let addresses = response as? NSArray {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.keyArray = addresses
                    vc.connectingView.removeConnectingView()
                    vc.performSegue(withIdentifier: "goDisplayHDMusig", sender: vc)
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if range == "" {
            
            range = "0 to 2000"
            
        }
        
        dict["range"] = range
        
        switch segue.identifier {
            
        case "addToKeypool":
            
            if let vc = segue.destination as? AddToKeypoolViewController  {
            
                vc.dict = dict
                vc.isDescriptor = isDescriptor
                
            }
            
        case "goDisplayHDMusig":
            
            if let vc = segue.destination as? ImportExtendedKeysViewController {
                
                vc.keyArray = keyArray
                vc.dict = dict
                vc.isHDMusig = true
                
            }
            
        default:
            
            break
            
        }
    }

}
