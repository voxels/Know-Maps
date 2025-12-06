//
//  OnboardingSubscriptionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

public enum SubscriptionPlanType :String {
    case free = "Free"
    case limited = "Limited"
    case monthly = "Monthly"
    case restoreSubscription = "Restore Subscription"
}

public struct SubscriptionPlan: Identifiable, Equatable, Hashable {
    public let id = UUID().uuidString
    public let plan:SubscriptionPlanType
}

struct OnboardingSubscriptionView: View {
    @ObservedObject public var model:AppleAuthenticationService
    @Binding  public var selectedTab:String
    @Binding  public var showOnboarding:Bool
    @State private var selectedSubscription:SubscriptionPlan?
    @State private var subscriptionIncomplete:Bool = true
    
    @State private var allPlans = [SubscriptionPlan(plan:.free), SubscriptionPlan(plan:.monthly)]
    
    var body: some View {
        VStack{
            Spacer()
            Text("Subscriptions").bold().padding()
            Image(systemName: "map.circle")
                .resizable()
                .scaledToFit()
                .frame(width:100 , height: 100)
            Text("Choose a plan to get started:")
                .multilineTextAlignment(.leading)
                .padding()
            
            List(allPlans, selection: $selectedSubscription){ plan in
                Button(plan.plan.rawValue, action: {
                    selectedSubscription = plan
//                    FeatureFlagService.shared.updateFlags(with: plan)
                })
            }.onChange(of: selectedSubscription) { oldValue, newValue in
                if let _ = newValue {
                    subscriptionIncomplete = false
                } else {
                    subscriptionIncomplete = true
                }
            }
            
            Button("Get Started") {
                selectedTab = "Saving"
            }
            .padding(EdgeInsets(top: 32, leading: 0, bottom: 64, trailing: 0))
            .disabled(subscriptionIncomplete)
        }
    }
}
