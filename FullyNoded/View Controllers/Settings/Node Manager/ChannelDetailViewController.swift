//
//  ChannelDetailViewController.swift
//  FullyNoded
//
//  Created by Peter on 18/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ChannelDetailViewController: UIViewController {
    
    var selectedChannel:[String:Any]?
    var channels = [[String:Any]]()
    var ours = [[String:Any]]()
    var theirs = [[String:Any]]()
    var myId = ""
    var paymentHash = ""
    var outgoingId = ""
    var incomingId = ""
    var routeOut = [String:Any]()
    var routeMid = [String:Any]()
    var routeIn = [String:Any]()
    var routes = [[String:Any]]()
    var excludes = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        parseChannels()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        selectCounterpart()
    }
    
    private func parseChannels() {
        /*
        excludes = []
        # excude all own channels to prevent unwanted shortcuts [out,mid,in]
        mychannels = plugin.rpc.listchannels(source=my_node_id)['channels']
        for channel in mychannels:
            excludes += [channel['short_channel_id'] + '/0', channel['short_channel_id'] + '/1']
        */
        for ch in channels {
            let ourAmount = ch["to_us_msat"] as? String ?? ""
            let totalAmount = ch["total_msat"] as? String ?? ""
            let ourAmountInt = Int(ourAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let totalAmountInt = Int(totalAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let ratio = Double(ourAmountInt) / Double(totalAmountInt)
            let shortId = ch["short_channel_id"] as! String
            excludes.append(shortId + "/0")
            excludes.append(shortId + "/1")
            if ratio > 0.9 {
                ours.append(ch)
            } else if ratio <= 0.1 {
                theirs.append(ch)
            }
        }
    }
    
    private func selectCounterpart() {
        if selectedChannel != nil {
            for ch in ours {
                if ch["short_channel_id"] as! String == selectedChannel!["short_channel_id"] as! String {
                    chooseTheirsCounterpart()
                }
            }
        }
    }
    
    private func chooseTheirsCounterpart()  {
        if theirs.count > 0 {
            let source = selectedChannel!["peerId"] as! String
            outgoingId = source
            let sourceShortId = selectedChannel!["short_channel_id"] as! String
            let msat = Int(Double(theirs[0]["receivable_msatoshi"] as! Int) / 2.0)
            let destination = theirs[0]["peerId"] as! String
            let destinationShortId = theirs[0]["short_channel_id"] as! String
            /*
             "amount_msat" = 43151000msat;
             channel = 643463x779x0;
             delay = 9;
             direction = 1;
             id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
             msatoshi = 43151000;
             style = tlv;
             */
            routeOut = ["amount_msat":"","channel":sourceShortId,"delay":9,"direction": !(myId < source),"id":source,"msatoshi":0,"style":"tlv"]
            routeIn = ["amount_msat":"","channel":destinationShortId,"delay":9,"direction": !(destination < myId),"id":myId,"msatoshi":0,"style":"tlv"]
            LightningRPC.command(method: .invoice, param: "\(msat), \"rebalance - \(Date())\", \"FullyNoded-\(randomString(length: 5))\"") { [weak self] (response, errorDesc) in
                if let dict = response as? NSDictionary {
                    if let hash = dict["payment_hash"] as? String {
                        self?.paymentHash = hash
                        self?.getRoute(destination, msat, source)
                    }
                }
            }
        }
    }
    
    func json(from object:Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
    private func getRoute(_ destinationId: String, _ msat: Int, _ fromId: String) {
        //getroute id msatoshi riskfactor [cltv] [fromid] [fuzzpercent] [exclude] [maxhops]
        //getroute(target, msatoshi, riskfactor=1, cltv=9, fromid=source)
        LightningRPC.command(method: .getroute, param: "\"\(destinationId)\", \(msat), 1, 9, \"\(fromId)\", 5.0, \(excludes)") { [weak self] (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let route = dict["route"] as? NSArray {
                    for r in route {
                        if let d = r as? NSDictionary {
                            self?.routeMid = d as! [String:Any]
                        }
                        
                        //if self?.json(from: r) != nil {
//                            var processed = ((self?.json(from: r)?.condenseWhitespace())!).replacingOccurrences(of: "\\", with: "")
//                            processed = processed.replacingOccurrences(of: "}\"", with: "}")
//                            processed = processed.replacingOccurrences(of: "\"{", with: "{")
                            
                        //}
                    }
                    self?.getFee(destinationId, msat)
                }
            } else {
                if self != nil {
                    let reduced = Int(Double(msat) / 1.1)
                    self?.getRoute(destinationId, reduced, fromId)
                }
            }
        }
    }
    /*
     route =         (
                     {
             "amount_msat" = 501005msat;
             channel = 643969x194x0;
             delay = 23;
             direction = 0;
             id = 03c304a6a6d64771aa70b05fbe1137dbcc7b585f6150acfd27680cf82c0913e579;
             msatoshi = 501005;
             style = tlv;
         },
                     {
             "amount_msat" = 500000msat;
             channel = 643983x1159x0;
             delay = 9;
             direction = 1;
             id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
             msatoshi = 500000;
             style = tlv;
         }
     )
     */
    
    private func getFee(_ destination: String, _ amount: Int) {
        var msatoshi = amount
        var delay = 9
        let routeGroup = DispatchGroup()
        routes = [routeOut, routeMid, routeIn]
        for (i, r) in routes.reversed().enumerated() {
            routeGroup.enter()
            routes[i]["msatoshi"] = amount
            routes[i]["amount_msat"] = "\(amount)msat"
            routes[i]["delay"] = delay
            if let channel = r["channel"] as? String {
                LightningRPC.command(method: .listchannels, param: "\"\(channel)\"") { (response, errorDesc) in
                    if let channelsResponse = response as? NSDictionary {
                        if let channels = channelsResponse["channels"] as? NSArray {
                            for channel in channels {
                                if let d = channel as? [String:Any] {
                                    if d["destination"] as! String == r["id"] as! String {
                                        /*
                                         fee = Millisatoshi(ch['base_fee_millisatoshi'])
                                         # BOLT #7 requires fee >= fee_base_msat + ( amount_to_forward * fee_proportional_millionths / 1000000 )
                                         fee += (msatoshi * ch['fee_per_millionth'] + 10**6 - 1) // 10**6 # integer math trick to round up
                                         msatoshi += fee
                                         delay += ch['delay']
                                         */
                                        
                                        var fee = d["base_fee_millisatoshi"] as! Int
                                        let feePerMillionth = d["fee_per_millionth"] as! Int
                                        fee += Int(Double((amount * feePerMillionth)) / 1000000.0)
                                        msatoshi += fee
                                        delay += d["delay"] as! Int
                                    }
                                }
                            }
                            routeGroup.leave()
                        }
                    }
                }
            }
        }
        routeGroup.notify(queue: .main) { [weak self] in
            if self != nil {
                self?.promptToRebalance(self!.routes.count, msatoshi, msatoshi - amount, amount)
            }
        }
    }
    
    private func promptToRebalance(_ nodeCount: Int, _ totalAmount: Int, _ totalFee: Int, _ originalAmount: Int) {
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Send circular payment to rebalance?", message: "Route contains \(nodeCount) nodes, amount including the fee: \(totalAmount), total fee: \(totalFee), amount to receive: \(originalAmount)", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { action in
                self?.sendNow()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    //var processed = ((self?.json(from: r)?.condenseWhitespace())!).replacingOccurrences(of: "\\", with: "")
    //                            processed = processed.replacingOccurrences(of: "}\"", with: "}")
    //                            processed = processed.replacingOccurrences(of: "\"{", with: "{")
    
    private func sendNow() {
        
//        var r = "[{\"id\":\(outgoingId)}, \(routes), {\"id\":\(myId)}]"
//        r = r.condenseWhitespace()
//        r = r.replacingOccurrences(of: "\\", with: "")
//        r = r.replacingOccurrences(of: "}\"", with: "}")
//        r = r.replacingOccurrences(of: "\"{", with: "{")
        //routeOut = ["amount_msat":"","channel":sourceShortId,"delay":9,"direction": !(myId < source),"id":source,"msatoshi":0,"style":"tlv"]
        //routeIn = ["amount_msat":"","channel":destinationShortId,"delay":9,"direction": !(destination < myId),"id":myId,"msatoshi":0,"style":"tlv"]
        
        let routeOutMsat = routes[0]["amount_msat"] as! String
        let routeOutSourceShortId = routes[0]["channel"] as! String
        let routeOutDirection = (routes[0]["direction"] as! Bool) ? 1 : 0
        let routeOutId = routes[0]["id"] as! String
        let routeOutMsatoshi = routes[0]["msatoshi"] as! Int

        let routeMidMsat = routeMid["amount_msat"] as! String
        let routeMidSourceShortId = routeMid["channel"] as! String
        let routeMidDirection = (routeMid["direction"] as! Bool) ? 1 : 0
        let routeMidId = routeMid["id"] as! String
        let routeMidMsatoshi = routeMid["msatoshi"] as! Int

        let routeInMsat = routes[2]["amount_msat"] as! String
        let routeInSourceShortId = routes[2]["channel"] as! String
        let routeInDirection = (routes[2]["direction"] as! Bool) ? 1 : 0
        let routeInId = routes[2]["id"] as! String
        let routeInMsatoshi = routes[2]["msatoshi"] as! Int
        
        /*
         "amount_msat" = 43151000msat;
                        channel = 643463x779x0;
                        delay = 9;
                        direction = 1;
                        id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
                        msatoshi = 43151000;
                        style = tlv;
         */
        
        let processedRoutes = "[[\"msatoshi\":\(routeOutMsatoshi),\"channel\":\"\(routeOutSourceShortId)\",\"delay\":9,\"direction\":\(routeOutDirection),\"id\":\"\(routeOutId)\", \"style\":\"tlv\"], [\"msatoshi\":\(routeMidMsatoshi),\"channel\":\"\(routeMidSourceShortId)\",\"delay\":9,\"direction\":\(routeMidDirection),\"id\":\"\(routeMidId)\", \"style\":\"tlv\"], [\"msatoshi\":\(routeInMsatoshi),\"channel\":\"\(routeInSourceShortId)\",\"delay\":9,\"direction\":\(routeInDirection),\"id\":\"\(routeInId)\", \"style\":\"tlv\"]]"
        LightningRPC.command(method: .sendpay, param: "[\(processedRoutes), \"\(paymentHash)\"") { (response, errorDesc) in
            if let dict = response as? NSDictionary {
                print("dict: \(dict)")
            }
        }
    }
    
//    private func chooseOursCounterpart() {
//        if ours.count > 0 {
//            let source = ours[0]["peerId"] as! String
//            let sourceShortId = ours[0]["short_channel_id"] as! String
//            let destination = selectedChannel!["peerId"] as! String
//            let destinationShortId = selectedChannel!["short_channel_id"] as! String
//            print("source: \(source)")
//            print("dest: \(destination)")
//            print("myId: \(myId)")
//            print("sourceShortId: \(sourceShortId)")
//            print("destinationShortId: \(destinationShortId)")
//        }
//    }
    
//    private func getChannelToPeer(peerId: String, completion: @escaping ((String?)) -> Void) {
//        LightningRPC.command(method: .listpeers, param: "\"\(peerId)\"") { (response, errorDesc) in
//            if let dict = response as? NSDictionary {
//                print("getPeerDict: \(dict)")
//            }
//        }
//    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
