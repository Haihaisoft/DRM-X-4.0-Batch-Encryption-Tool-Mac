import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @Binding var isLoggedIn: Bool
    @Binding var currentUser: User?
    
    var body: some View {
        
        let isChinese = currentUser?.isChineseVersion ?? false
        
        VStack {
            HStack {
                Text(localized("drmx_auto_encryption_tool", isChinese: isChinese))
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let user = currentUser {
                    Text("\(localized("welcome", isChinese: isChinese)) \(user.adminemail)")
                        .foregroundColor(.secondary)
                    
                    Button(localized("sign_out", isChinese: isChinese)) {
                        isLoggedIn = false
                        currentUser = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            TabView(selection: $selectedTab) {
                ManualEncryptionView(user: currentUser)
                    .tabItem {
                        Label(localized("manual_encryption", isChinese: isChinese), systemImage: "doc.fill")
                    }
                    .tag(0)
                
                AutoEncryptionView(user: currentUser)
                    .tabItem {
                        Label(localized("auto_encryption", isChinese: isChinese), systemImage: "clock.fill")
                    }
                    .tag(1)
            }
        }
        .frame(width: 800, height: 600)
    }
}
