//
//  ChatHostingViewControllerDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation

public protocol ChatHostingViewControllerDelegate : AnyObject {
    func didTap(chatResult:ChatResult) async
}
