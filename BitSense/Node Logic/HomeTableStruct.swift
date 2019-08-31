//
//  HomeTableStruct.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation


public struct HomeStruct: CustomStringConvertible {
    
    let network:String
    let hashrate:String
    let amount:Double
    let coldBalance:String
    let version:String
    let torReachable:Bool
    let incomingCount:Int
    let outgoingCount:Int
    let blockheight:Int
    let difficulty:String
    let size:String
    let progress:String
    let pruned:Bool
    let unconfirmedBalance:String
    let hotBalance:String
    let mempoolCount:Int
    let transactions:[[String: Any]]
    let uptime:Int
    
    /*
    
    let departureLat:Double
    let departureLon:Double
    let departureTerminal:String
    let departureDate:String
    let departureUtcOffset:Double
    let flightDuration:String
    let airplaneType:String
    let flightId:String
    let flightStatus:String
    let identifier:String
    let phoneNumber:String
    let primaryCarrier:String
    let publishedArrival:String
    let publishedDeparture:String
    let urlArrivalDate:String*/
    
    init(dictionary: [String: Any]) {
        
        self.uptime = dictionary["uptime"] as? Int ?? 0
        self.network = dictionary["chain"] as? String ?? ""
        self.hashrate = dictionary["networkhashps"] as? String ?? ""
        self.amount = dictionary["amount"] as? Double ?? 0.0
        self.coldBalance = dictionary["coldBalance"] as? String ?? "0.00000000"
        self.version = dictionary["subversion"] as? String ?? ""
        self.torReachable = dictionary["reachable"] as? Bool ?? false
        self.incomingCount = dictionary["incomingCount"] as? Int ?? 0
        self.outgoingCount = dictionary["outgoingCount"] as? Int ?? 0
        self.blockheight = dictionary["blocks"] as? Int ?? 0
        self.difficulty = dictionary["difficulty"] as? String ?? ""
        self.size = dictionary["size"] as? String ?? ""
        self.progress = dictionary["progress"] as? String ?? ""
        self.pruned = dictionary["pruned"] as? Bool ?? false
        self.unconfirmedBalance = dictionary["unconfirmedBalance"] as? String ?? "0.00000000"
        self.hotBalance = dictionary["hotBalance"] as? String ?? ""
        self.mempoolCount = dictionary["mempoolCount"] as? Int ?? 0
        self.transactions = dictionary["transactions"] as? [[String: Any]] ?? []
        
        
        /*self.departureLat = dictionary["departureLat"] as? Double ?? 0
        self.departureLon = dictionary["departureLon"] as? Double ?? 0
        self.departureTerminal = dictionary["departureTerminal"] as? String ?? ""
        self.departureDate = dictionary["departureTime"] as? String ?? ""
        self.departureUtcOffset = dictionary["departureUtcOffset"] as? Double ?? 0
        self.flightDuration = dictionary["flightDuration"] as? String ?? ""
        self.airplaneType = dictionary["flightEquipment"] as? String ?? ""
        self.flightId = dictionary["flightId"] as? String ?? ""
        self.flightStatus = dictionary["flightStatus"] as? String ?? ""
        self.identifier = dictionary["identifier"] as? String ?? ""
        self.phoneNumber = dictionary["phoneNumber"] as? String ?? ""
        self.primaryCarrier = dictionary["primaryCarrier"] as? String ?? ""
        self.publishedArrival = dictionary["publishedArrival"] as? String ?? ""
        self.publishedDeparture = dictionary["publishedDeparture"] as? String ?? ""
        self.urlArrivalDate = dictionary["urlArrivalDate"] as? String ?? ""
        self.lastUpdated = dictionary["lastUpdated"] as? String ?? ""
        self.sharedFrom = dictionary["sharedFrom"] as? String ?? ""*/
        
    }
    
    public var description: String {
        return ""
    }
    
}
