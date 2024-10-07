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
    public let id = UUID()
    public let plan:SubscriptionPlanType
}

struct OnboardingSubscriptionView: View {
    @Binding public var selectedTab:String
    @Binding public var showOnboarding:Bool
    @EnvironmentObject public var featureFlags:FeatureFlags
    @EnvironmentObject public var model:AuthenticationManager
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
                    featureFlags.updateFlags(with: plan)
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

struct SingleSelectionList<Item: Identifiable, Content: View>: View {
    
    var items: [Item]
    @Binding var selectedItem: Item?
    var rowContent: (Item) -> Content
    
    var body: some View {
        List(items) { item in
            rowContent(item)
                .modifier(CheckmarkModifier(checked: item.id == self.selectedItem?.id))
                .contentShape(Rectangle())
        }
    }
}

struct CheckmarkModifier: ViewModifier {
    var checked: Bool = false
    func body(content: Content) -> some View {
        Group {
            if checked {
                HStack() {
                    content
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.blue)
                }
            } else {
                content
            }
        }
    }
}

#Preview {
    return OnboardingSubscriptionView(selectedTab: .constant("Subscription"), showOnboarding: .constant(true))
}
