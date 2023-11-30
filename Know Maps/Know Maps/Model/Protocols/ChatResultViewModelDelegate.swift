//
//  File.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import CoreLocation

public protocol ChatResultViewModelDelegate : AnyObject {
    func didUpdateModel(for location:CLLocation?)
}
