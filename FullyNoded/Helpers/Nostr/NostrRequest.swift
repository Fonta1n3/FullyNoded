//
//  NostrRequest.swift
//  damus
//
//  Created by William Casarin on 2022-04-11.
//
// Copied and modified by Peter Denton on 2022-10-21

import Foundation

struct NostrSubscribe {
    let filters: [NostrFilter]
    let sub_id: String
}

enum NostrRequest {
    case subscribe(NostrSubscribe)
    case unsubscribe(String)
    case event(NostrEvent)
}
