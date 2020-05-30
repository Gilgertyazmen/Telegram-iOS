//
//  RegDate.swift
//  NicegramLib
//
//  Created by Sergey on 23.11.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import SwiftSignalKit

let ngLabData = bconfig.ngLabData.components(separatedBy: ",")


public enum RegDateError {
    case generic
}

public func requestRegDate(jsonData: Data) -> Signal<Date, RegDateError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        var request = URLRequest(url: URL(string: ngLabData[0] + "regdate")!)
        
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        // insert json data to the request
        request.httpBody = jsonData as Data
        request.timeoutInterval = 10
        let downloadTask = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            let _ = completed.swap(true)
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    if let data = data {
                        if let result = String(data: data, encoding: .utf8) {
                            if let timeInterval = TimeInterval(result) {
                                let date = Date(timeIntervalSince1970: timeInterval)
                                subscriber.putNext(date)
                                subscriber.putCompletion()
                            } else {
                                subscriber.putError(.generic)
                            }
                        } else {
                            subscriber.putError(.generic)
                        }
                    } else {
                        subscriber.putError(.generic)
                    }
                } else {
                    subscriber.putError(.generic)
                }
            } else {
                subscriber.putError(.generic)
            }
        })
        downloadTask.resume()
        
        return ActionDisposable {
            if !completed.with({ $0 }) {
                downloadTask.cancel()
            }
        }
    }
}


public func getRegDate(_ userId: Int64, owner: Int64
    ) -> Signal<Date, RegDateError> {
    return Signal { subscriber in
        let requestSignal = requestRegDate(jsonData: prepareRegDateData(userId, owner: owner))
        
        let _ = (requestSignal |> deliverOnMainQueue).start(next: {
            responseDate in
            setCachedRegDate(userId, Int(responseDate.timeIntervalSince1970))
            subscriber.putNext(responseDate)
            subscriber.putCompletion()
        }, error: { _ in
            subscriber.putError(.generic)
        })
        
        return ActionDisposable {
        }
    }
}

func prepareRegDateData(_ userId: Int64, owner: Int64) -> Data {
    let json = ["user_id": userId, "owner": owner, "data": ngLabData[1]] as [String : Any]
    let jsonData = try! JSONSerialization.data(withJSONObject: json)
    return jsonData
}

public func getCachedRegDate(_ userId: Int64) -> Date? {
    let UD = UserDefaults(suiteName: "CachedRegDate")
    if let regDate = UD?.integer(forKey: "RD:\(userId)"), regDate != 0 {
        return Date(timeIntervalSince1970: TimeInterval(regDate))
    }
    
    return nil
}

public func setCachedRegDate(_ userId: Int64, _ ts: Int) -> Void {
    let UD = UserDefaults(suiteName: "CachedRegDate")
    UD?.set(ts, forKey: "RD:\(userId)")
}

public func makeNiceRegDateStr(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC") //Set timezone that you want
    dateFormatter.locale = NSLocale.current
    dateFormatter.setLocalizedDateFormatFromTemplate("MMMMy")
    return dateFormatter.string(from: date)
}


public func resetRegDateCache() -> Void {
    UserDefaults.standard.removePersistentDomain(forName: "CachedRegDate")
}
