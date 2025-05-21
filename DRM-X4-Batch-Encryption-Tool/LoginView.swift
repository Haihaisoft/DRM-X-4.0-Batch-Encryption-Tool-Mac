import SwiftUI

struct LoginView: View {
    @State private var adminemail: String = ""
    @State private var webServiceCode: String = ""
    @State private var rememberLogin: Bool = true
    @State private var isChineseVersion: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    @Binding var isLoggedIn: Bool
    @Binding var currentUser: User?
    
    // Add UserDefaults key constants
    private let kAdminEmail = "savedAdminEmail"
    private let kWebServiceCode = "savedWebServiceCode"
    private let kIsChineseVersion = "savedIsChineseVersion"
    private let kRememberLogin = "savedRememberLogin"
    
    private var serviceURL: String {
        isChineseVersion ? "https://4.drm-x.cn/haihaisoftlicenseservice.asmx" : "https://4.drm-x.com/haihaisoftlicenseservice.asmx"
    }
    private var soapAction: String {
        isChineseVersion ? "https://4.drm-x.cn/haihaisoftlicenseservice.asmx?op=WebServiceLogin" : "https://4.drm-x.com/haihaisoftlicenseservice.asmx?op=WebServiceLogin"
    }
    
    private var registerURL: String {
        isChineseVersion ? "https://4.drm-x.cn/Register.aspx" : "https://4.drm-x.com/Register.aspx"
    }
    
    private let tutorialURL = "https://www.drm-x.com/DRM-X-4.0-Automatic-Batch-Encryption-Tool.aspx"
    
    // MARK: - Login screen
    var body: some View {

        VStack(spacing: 20) {
            Text(localized("drmx_auto_encryption_tool", isChinese: isChineseVersion))
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(width: 550)
            
            HStack(spacing: 20) {
                Toggle(isOn: Binding(
                    get: { !isChineseVersion },
                    set: { newValue in
                        if newValue {
                            isChineseVersion = false
                        }
                    }
                )) {
                    Text("International")
                }
                .padding()
                .frame(width: 140)
                
                Toggle(isOn: Binding(
                    get: { isChineseVersion },
                    set: { newValue in
                        if newValue {
                            isChineseVersion = true
                        }
                    }
                )) {
                    Text("中国版")
                }
                .padding()
                .frame(width: 140)
            }
            
            TextField(localized("drmx_account", isChinese: isChineseVersion), text: $adminemail)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            SecureField(localized("web_auth_string", isChinese: isChineseVersion), text: $webServiceCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            Toggle(localized("remember_login", isChinese: isChineseVersion), isOn: $rememberLogin)
                .frame(width: 300, alignment: .leading)
            
            if !errorMessage.isEmpty {
                Text(isChineseVersion ? errorMessage : localized("please_enter_account_and_auth_string", isChinese: isChineseVersion))
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(localized("sign_in", isChinese: isChineseVersion))
                            .frame(width: 100,height: 35)
                    }
                }
                .disabled(isLoading)
                .buttonStyle(.borderedProminent)
                
                Button(action: register) {
                    Text(localized("sign_up", isChinese: isChineseVersion))
                        .frame(width: 100, height: 35)
                }
                .buttonStyle(.bordered)
            }
            
            Button(action: openTutorial) {
                Text(localized("tutorial", isChinese: isChineseVersion))
                    .foregroundColor(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
    
    // MARK: Load saved data at initialization
    init(isLoggedIn: Binding<Bool>, currentUser: Binding<User?>) {
        self._isLoggedIn = isLoggedIn
        self._currentUser = currentUser
        
        // Loading saved data from UserDefaults
        let defaults = UserDefaults.standard
        let savedRememberLogin = defaults.bool(forKey: kRememberLogin)
        
        if savedRememberLogin {
            _adminemail = State(initialValue: defaults.string(forKey: kAdminEmail) ?? "")
            _webServiceCode = State(initialValue: defaults.string(forKey: kWebServiceCode) ?? "")
            _isChineseVersion = State(initialValue: defaults.bool(forKey: kIsChineseVersion))
        }
        _rememberLogin = State(initialValue: savedRememberLogin)
    }
    
    // MARK: Login
    private func login() {
        guard !adminemail.isEmpty, !webServiceCode.isEmpty else {
            errorMessage = localized("please_enter_account_and_auth_string", isChinese: isChineseVersion)
            return
        }
        
        // Save login information
        if rememberLogin {
            let defaults = UserDefaults.standard
            defaults.set(adminemail, forKey: kAdminEmail)
            defaults.set(webServiceCode, forKey: kWebServiceCode)
            defaults.set(isChineseVersion, forKey: kIsChineseVersion)
            defaults.set(rememberLogin, forKey: kRememberLogin)
        } else {
            // If not select Remember login, clear the saved information
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: kAdminEmail)
            defaults.removeObject(forKey: kWebServiceCode)
            defaults.removeObject(forKey: kIsChineseVersion)
            defaults.set(false, forKey: kRememberLogin)
        }
        
        isLoading = true
        errorMessage = ""
        
        let client = SOAPClient()
        client.login(endpoint: serviceURL,
                     soapAction: soapAction,
                     email: adminemail,
                     authStr: webServiceCode) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                if let result = result?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if let adminID = Int(result), adminID > 0 {
                        print("✅ Login successful, return user ID: \(adminID)")
                        self.currentUser = User(adminemail: self.adminemail,
                                                webServiceCode: self.webServiceCode,
                                                isChineseVersion: self.isChineseVersion,
                                                adminId: result)
                        self.isLoggedIn = true
                        return
                    } else if result == "-2" {
                        self.errorMessage = localized("account_type_not_supported", isChinese: isChineseVersion)
                        return
                    } else if result == "-3" {
                        self.errorMessage = localized("account_or_code_incorrect", isChinese: isChineseVersion)
                        return
                    } else {
                        self.errorMessage = localized("login_failed_please_check", isChinese: isChineseVersion)
                        return
                    }
                } else {
                    print("❌ Login failed or parsing failed")
                    self.errorMessage = localized("login_failed_please_check_network", isChinese: isChineseVersion)
                }

            }
        }
       
    }
    
    // MARK: Register
    private func register() {
        NSWorkspace.shared.open(URL(string: registerURL)!)
    }
    
    private func openTutorial() {
        NSWorkspace.shared.open(URL(string: tutorialURL)!)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isLoggedIn: .constant(false), currentUser: .constant(nil))
    }
}
