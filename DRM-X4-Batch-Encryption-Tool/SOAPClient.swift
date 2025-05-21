import Foundation

class SOAPClient: NSObject {
    
    // MARK: 登录验证接口
    func login(endpoint: String, soapAction: String, email: String, authStr: String, completion: @escaping (String?) -> Void) {
        // 1. 构造SOAP XML
        let soapMessage = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
            <soap12:Body>
                <WebServiceLogin xmlns="http://tempuri.org/ASPNET.StarterKit.Commerce/HaihaisoftLicenseService">
                    <AdminEmail>\(email)</AdminEmail>
                    <WebServiceAuthStr>\(authStr)</WebServiceAuthStr>
                </WebServiceLogin>
            </soap12:Body>
        </soap12:Envelope>
        """
        
        // 2. 创建 URLRequest
        guard let url = URL(string: endpoint) else {
            print("URL错误")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(soapAction, forHTTPHeaderField: "SOAPAction")
        request.addValue(String(soapMessage.utf8.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = soapMessage.data(using: .utf8)
        
        // 3. 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("没有返回数据")
                completion(nil)
                return
            }
            
            // 打印响应数据
            if let responseString = String(data: data, encoding: .utf8) {
                //print("服务器返回数据：\n\(responseString)")
                
                // 使用简单的字符串处理来提取 WebServiceLoginResult 的值
                if let startRange = responseString.range(of: "<WebServiceLoginResult>"),
                   let endRange = responseString.range(of: "</WebServiceLoginResult>") {
                    let start = startRange.upperBound
                    let end = endRange.lowerBound
                    let result = String(responseString[start..<end])
                    
                    completion(result)
                    return
                }
            }
            
            completion(nil)
        }
        
        task.resume()
    }
    
    // MARK: 获取许可证模板列表
    func listLicenseProfiles(endpoint: String, soapAction: String,  adminemail: String, authStr: String, completion: @escaping (String?) -> Void) {
        // 构造SOAP XML
        let soapMessage = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
            <soap12:Body>
                <ListLicenseProfilesAsString xmlns="http://tempuri.org/ASPNET.StarterKit.Commerce/HaihaisoftLicenseService">
                    <AdminEmail>\(adminemail)</AdminEmail>
                    <WebServiceAuthStr>\(authStr)</WebServiceAuthStr>
                    <GroupID>-1</GroupID>
                </ListLicenseProfilesAsString>
            </soap12:Body>
        </soap12:Envelope>
        """
        
        // 创建 URLRequest
        guard let url = URL(string: endpoint) else {
            print("URL错误")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(soapAction, forHTTPHeaderField: "SOAPAction")
        request.addValue(String(soapMessage.utf8.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = soapMessage.data(using: .utf8)
        
        // 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("没有返回数据")
                completion(nil)
                return
            }
            
            // 解析响应数据
            if let responseString = String(data: data, encoding: .utf8) {
                //print("服务器返回数据：\n\(responseString)")
                
                // 提取 ListLicenseProfilesAsStringResult 的值
                if let startRange = responseString.range(of: "<ListLicenseProfilesAsStringResult>"),
                   let endRange = responseString.range(of: "</ListLicenseProfilesAsStringResult>") {
                    let start = startRange.upperBound
                    let end = endRange.lowerBound
                    let result = String(responseString[start..<end])
                    completion(result)
                    return
                }
            }
            
            completion(nil)
        }
        
        task.resume()
    }
    
    // MARK: 添加许可证模板
    func addLicenseProfile(endpoint: String, soapAction: String, adminemail: String, authStr: String, profileName: String, productID: String, forceInternet: String, completion: @escaping (String?) -> Void) {
        
        // 构造SOAP XML
        let soapMessage = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
            <soap12:Body>
                <AddLicenseProfile xmlns="http://tempuri.org/ASPNET.StarterKit.Commerce/HaihaisoftLicenseService">
                    <AdminEmail>\(adminemail)</AdminEmail>
                    <WebServiceAuthStr>\(authStr)</WebServiceAuthStr>
                    <ProfileName>\(profileName)</ProfileName>
                    <YourProductID>\(productID)</YourProductID>
                    <ForceInternet>\(forceInternet)</ForceInternet>
                </AddLicenseProfile>
            </soap12:Body>
        </soap12:Envelope>
        """
        
        // 创建 URLRequest
        guard let url = URL(string: endpoint) else {
            print("URL错误")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(soapAction, forHTTPHeaderField: "SOAPAction")
        request.addValue(String(soapMessage.utf8.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = soapMessage.data(using: .utf8)
        
        // 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("📭 没有返回数据")
                completion(nil)
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {

                if let startRange = responseString.range(of: "<AddLicenseProfileResult>"),
                   let endRange = responseString.range(of: "</AddLicenseProfileResult>") {
                    let start = startRange.upperBound
                    let end = endRange.lowerBound
                    let result = String(responseString[start..<end])
                    completion(result)
                    return
                }
            }

            completion(nil)
        }
        
        task.resume()
    }


    // MARK: 获取许可证权限列表
    func listRights(endpoint: String, soapAction: String,  adminemail: String, authStr: String, completion: @escaping (String?) -> Void) {
        // 构造SOAP XML
        let soapMessage = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
            <soap12:Body>
                <ListRightsAsString xmlns="http://tempuri.org/ASPNET.StarterKit.Commerce/HaihaisoftLicenseService">
                    <AdminEmail>\(adminemail)</AdminEmail>
                    <WebServiceAuthStr>\(authStr)</WebServiceAuthStr>
                    <LicenseProfileID>-1</LicenseProfileID>
                </ListRightsAsString>
            </soap12:Body>
        </soap12:Envelope>
        """
        
        // 创建 URLRequest
        guard let url = URL(string: endpoint) else {
            print("URL错误")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(soapAction, forHTTPHeaderField: "SOAPAction")
        request.addValue(String(soapMessage.utf8.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = soapMessage.data(using: .utf8)
        
        // 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("没有返回数据")
                completion(nil)
                return
            }
            
            // 解析响应数据
            if let responseString = String(data: data, encoding: .utf8) {
                //print("服务器返回数据：\n\(responseString)")
                
                // 提取 ListRightsAsStringResult 的值
                if let startRange = responseString.range(of: "<ListRightsAsStringResult>"),
                   let endRange = responseString.range(of: "</ListRightsAsStringResult>") {
                    let start = startRange.upperBound
                    let end = endRange.lowerBound
                    let result = String(responseString[start..<end])
                    completion(result)
                    return
                }
            }
            
            completion(nil)
        }
        
        task.resume()
    }


    // MARK: 添加权限到许可证模板
    func addRightToLicenseProfile(
        endpoint: String,
        soapAction: String,
        adminemail: String,
        authStr: String,
        rightID: Int,
        licenseProfileID: Int,
        completion: @escaping (String?) -> Void
    ) {
        let soapMessage = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                        xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
            <soap12:Body>
                <AddRightToLicenseProfile xmlns="http://tempuri.org/ASPNET.StarterKit.Commerce/HaihaisoftLicenseService">
                <AdminEmail>\(adminemail)</AdminEmail>
                <WebServiceAuthStr>\(authStr)</WebServiceAuthStr>
                <RightID>\(rightID)</RightID>
                <LicenseProfileID>\(licenseProfileID)</LicenseProfileID>
                </AddRightToLicenseProfile>
            </soap12:Body>
        </soap12:Envelope>
        """
        
        // 创建 URLRequest
        guard let url = URL(string: endpoint) else {
            print("URL错误")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(soapAction, forHTTPHeaderField: "SOAPAction")
        request.addValue(String(soapMessage.utf8.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = soapMessage.data(using: .utf8)
        
        // 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("没有返回数据")
                completion(nil)
                return
            }
            
            // 解析响应数据
            if let responseString = String(data: data, encoding: .utf8) {
                //print("服务器返回数据：\n\(responseString)")
                
                // 提取 ListRightsAsStringResult 的值
                if let startRange = responseString.range(of: "<AddRightToLicenseProfileResult>"),
                   let endRange = responseString.range(of: "</AddRightToLicenseProfileResult>") {
                    let start = startRange.upperBound
                    let end = endRange.lowerBound
                    let result = String(responseString[start..<end])
                    completion(result)
                    return
                }
            }
            
            completion(nil)
        }
        
        task.resume()
    }
}

