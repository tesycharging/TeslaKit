//
//  TeslaAPI.swift
//  TeslaApp
//
//  Created by Jaren Hamblin on 11/19/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//
//  Update by David Lüthi on 10.06.2021
//

import Foundation
import ObjectMapper
import WebKit
import Combine

///
public protocol TeslaAPIDelegate: AnyObject {

    ///
    func teslaApiActivityDidBegin(_ teslaAPI: TeslaAPI)

    ///
    func teslaApiActivityDidEnd(_ teslaAPI: TeslaAPI, response: HTTPURLResponse, error: Error?)

    ///
    func teslaApi(_ teslaAPI: TeslaAPI, didSend command: Command, data: CommandResponse?, result: CommandResponse)
}


private var nullBody = ""
///
open class TeslaAPI: NSObject, URLSessionDelegate {
    open fileprivate(set) var token: AuthToken?
    open var webLoginProcess = false
    
    ///
    public struct Configuration {

        ///
        public let baseURL: URL

        /// Tesla API owner api client id
        public let clientId: String

        /// Tesla API owner api client secret
        public let clientSecret: String

        ///
        public let apiVersion: Int = 1

        ///
        public let requestTimeout: TimeInterval

        ///
        public var apiBaseURL: URL { return self.baseURL.appendingPathComponent("api/\(self.apiVersion)") }

        ///
        public static let `default`: Configuration = Configuration(baseURL: URL(string: "https://owner-api.teslamotors.com")!,
                                                                   clientId: "e4a9949fcfa04068f59abb5a658f2bac0a3428e4652315490b659d5ab3f35a9e",
                                                                   clientSecret: "c75f14bbadc8bee3a7594412c31416f8300256d7668ea7e6e7f06727bfb9d220",
                                                                   requestTimeout: 30)

        ///
        public static let mock: Configuration = Configuration(baseURL: URL(string: "https://us-central1-teslaapp-dev.cloudfunctions.net/mock")!,
                                                              clientId: "",
                                                              clientSecret: "",
                                                              requestTimeout: 10)

    }

    public let configuration: Configuration

    ///
    public var debugMode: Bool = false

    ///
    public weak var delegate: TeslaAPIDelegate? = nil

    ///
    public var session: URLSession

    ///
    public var headers: [String: String] = [
        "content-type": "application/json",
        "cache-control": "no-cache"
    ]


    /// Initialize a new instance of TeslaAPI
    public convenience init(configuration: Configuration = Configuration.default, debugMode: Bool = false) {
        self.init(configuration: configuration,
                  session: URLSession(configuration: .default),
                  debugMode: debugMode)
    }

    /// Initialize a new instance of TeslaAPI
    public init(configuration: Configuration = Configuration.default, session: URLSession, debugMode: Bool = false) {
        self.configuration = configuration
        self.debugMode = debugMode
        self.session = session
    }

    ///
    public func request<T: Mappable>(_ url: URL, method: String = "GET", parameters: Any? = nil, headers: [String: String] = [:], completion: @escaping (HTTPURLResponse, T?, Error?) -> Void) {

        // Create the request
        let request: URLRequest = {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2 * self.configuration.requestTimeout)
            request.httpMethod = method
            request.setValue("TesyCharging", forHTTPHeaderField: "User-Agent")
            
            if let token = self.token?.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
           
            if let parameters = parameters {
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
            }
            return request
        }()

        // Create the task
        let task = self.session.dataTask(with: request) { (dataOrNil, responseOrNil, errorOrNil) in

            let response: HTTPURLResponse = (responseOrNil as? HTTPURLResponse) ?? HTTPURLResponse(url: url, statusCode: 0, httpVersion: nil, headerFields: headers)!

            self.delegate?.teslaApiActivityDidEnd(self, response: response, error: errorOrNil)

            var mappedData: T? = nil

            // If debug mode, print out contents of response
            if self.debugMode {
                self.debugPrint(request, response: response, responseData: dataOrNil, error: errorOrNil)
            }

            // Attempt to serialize the response JSON and map to TeslaKit objects
            do {
                if let data = dataOrNil {
                    let json: Any = try JSONSerialization.jsonObject(with: data)
                    mappedData = Mapper<T>().map(JSONObject: json)
                }
            } catch let error {
                print(error.localizedDescription)
            }

            // Call the completion handler
            DispatchQueue.main.async {
                /*print("*********************")
                var i = 0
                 var s = ""
                 while(i<dataOrNil!.count) {
                     s = s + String(UnicodeScalar(UInt8(dataOrNil![i])))
                     i = i + 1
                 }
                 print(s)
                print("*********************")*/
                completion(response, mappedData, errorOrNil)
            }
        }

        self.delegate?.teslaApiActivityDidBegin(self)

        // Start the task immediately
        task.resume()
    }
    
    func teslaRequest<ReturnType: Decodable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, completion: @escaping (Result<ReturnType, Error>) -> ()) -> Void {
        // Create the request
        let request = prepareRequest(endpoint, body: body)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            (data, response, error) in
            
            
            guard error == nil else { completion(Result.failure(error!)); return }
            guard let httpResponse = response as? HTTPURLResponse else { completion(Result.failure(TeslaError.failedToParseData)); return }
            
            if case 200..<300 = httpResponse.statusCode {
                
                do {
                    if let data = data {
                        
                        let mapped = try teslaJSONDecoder.decode(ReturnType.self, from: data)
                        completion(Result.success(mapped))
                    }
                } catch {
                    //print("ERROR: \(error)")
                    completion(Result.failure(TeslaError.failedToParseData))
                }
                
            } else {
                if let data = data {
                    
                    if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
                        wwwauthenticate.contains("invalid_token") {
                        completion(Result.failure(TeslaError.tokenRevoked))
                    } else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
                        completion(Result.failure(TeslaError.authenticationFailed))
                    } else if let mapped = try? teslaJSONDecoder.decode(ErrorMessage.self, from: data) {
                        completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:[ErrorInfo: mapped]))))
                    } else {
                        completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))))
                    }
                    
                } else {
                    if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String {
                        if wwwauthenticate.contains("invalid_token") {
                            completion(Result.failure(TeslaError.authenticationFailed))
                        }
                    } else {
                        completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))))
                    }
                }
            }
            
            
        })
        task.resume()
        
    }
    
    func prepareRequest<BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType) -> URLRequest {

        var urlComponents = URLComponents(url: URL(string: endpoint.baseURL(false))!, resolvingAgainstBaseURL: true)
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = endpoint.method
        
        request.setValue("TeslaSwift", forHTTPHeaderField: "User-Agent")
        
        if let token = self.token?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body as? String, body == nullBody {
        } else {
            request.httpBody = try? teslaJSONEncoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        return request
    }
    
    
    // MARK: - Core API
    
    /**
     Performs the authentition with the Tesla API for web logins

     For MFA users, this is the only way to authenticate.
     If the token expires, a token refresh will be done

     - parameter completion:      The completion handler when the token as been retrived
     - returns: A ViewController that your app needs to present. This ViewContoller will ask the user for his/her Tesla credentials, MFA code if set and then desmiss on successful authentication
     */
    #if canImport(WebKit) && canImport(UIKit)
    @available(iOS 13.0, *)
    public func authenticateWeb(completion: @escaping (Result<AuthToken, Error>) -> ()) -> TeslaWebLoginViewContoller? {
        WebCacheCleaner.clean()
        let codeRequest = AuthCodeRequest()
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters

        guard let safeUrlComponents = urlComponents else {
            completion(Result.failure(TeslaError.authenticationFailed))
            return nil
        }

        let teslaWebLoginViewContoller = TeslaWebLoginViewContoller(url: safeUrlComponents.url!)

        teslaWebLoginViewContoller.result = { result in
            switch result {
                case let .success(url):
                    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
                    if let queryItems = urlComponents?.queryItems {
                        for queryItem in queryItems {
                            if queryItem.name == "code", let code = queryItem.value {
                                self.getAuthenticationTokenforWeb(code: code, completion: completion)
                                return
                            }
                        }
                    }
                    completion(Result.failure(TeslaError.authenticationFailed))
                case let .failure(error):
                    completion(Result.failure(error))
            }
        }

        return teslaWebLoginViewContoller
    }
    #endif
    
    
    private func getAuthenticationTokenforWeb(code: String, completion: @escaping (Result<AuthToken, Error>) -> ()) {
        let body = AuthTokenRequestWeb(code: code)
        teslaRequest(.oAuth2Token, body: body) { [weak self] (result: Result<AuthToken, Error>) in

            DispatchQueue.main.async {
                switch result {
                    case .success(let token):
                        self?.token = token
                        UserDefaults.standard.set(self?.token.jsonString, forKey: "teslatoken")
                        completion(Result.success(token))
                    case .failure(let error):
                        if case let TeslaError.networkError(error: internalError) = error {
                            if internalError.code == 401 {
                                completion(Result.failure(TeslaError.authenticationFailed))
                            } else {
                                completion(Result.failure(error))
                            }
                        } else {
                            completion(Result.failure(error))
                        }
                }
            }
        }

    }
    
    
    /**
    Use this method to reuse a previous authentication token
    
    This method is useful if your app wants to ask the user for credentials once and reuse the token skiping authentication
    If the token is invalid a new authentication will be required
    
    - parameter token:      The previous token
    - parameter email:      Email is required for streaming
    */
    public func reuse(token: AuthToken) {
        self.token = token
    }
    
    
    /**
     Performs the token refresh with the Tesla API for Web logins

     - returns: A completion handler with the AuthToken.
     */
    public func refreshWebToken(completion: @escaping (Result<AuthToken, Error>) -> ()) -> Void {
        guard let token = self.token else {
            completion(Result.failure(TeslaError.noTokenToRefresh))
            return
        }
        let body = AuthTokenRequestWeb(grantType: .refreshToken, refreshToken: token.refreshToken)

        teslaRequest(.oAuth2Token, body: body) { (result: Result<AuthToken, Error>) in

            switch result {
                case .success(let token):
                    self.token = token
                UserDefaults.standard.set(self.token.jsonString, forKey: "teslatoken")
                completion(Result.success(token))
                case .failure(let error):
                    if case let TeslaError.networkError(error: internalError) = error {
                        if internalError.code == 401 {
                            completion(Result.failure(TeslaError.tokenRefreshFailed))
                        } else {
                            completion(Result.failure(error))
                        }
                    } else {
                        completion(Result.failure(error))
                    }
            }

        }

    }
    
    
    /**
     Revokes the stored token. Not working

     - returns: A completion handler with the token revoke state.
     */
    public func revokeWeb(completion: @escaping (Result<Bool, Error>) -> ()) -> Void {
        guard let accessToken = self.token?.accessToken else {
            WebCacheCleaner.clean()
            return completion(Result.success(false))
        }

        checkAuthentication { (result: Result<AuthToken, Error>) in
            WebCacheCleaner.clean()

            switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):

                    self.teslaRequest(.oAuth2revoke(token: accessToken), body: nullBody) { (result: Result<BoolResponse, Error>) in
                        switch result {
                            case .failure(let error):
                                completion(Result.failure(error))
                            case .success(let data):
                                completion(Result.success(data.response))
                        }
                    }
            }
        }
    }
    
    
    public func isAuthenticated(demo: Bool = false) -> Bool {
        if demo {
            return true
        } else {
            return token != nil && (token?.isValid ?? false)
        }
    }

    
    func checkToken() -> Bool {
        if let token = self.token {
            return token.isValid
        } else {
            return false
        }
    }
    
    public func checkAuthentication(completion: @escaping (Result<AuthToken, Error>) -> ()) {
        guard let token = self.token else { completion(Result.failure(TeslaError.authenticationRequired)); return }

        if checkToken() {
            completion(Result.success(token))
        } else {
            if token.refreshToken != nil {
                refreshWebToken(completion: completion)
            } else {
                completion(Result.failure(TeslaError.authenticationRequired))
            }
        }
    }

    /*/// Set the accessToken to be used with all requests
    ///
    /// - Parameter accessToken: String
    public func setAccessToken(_ accessToken: String?) {
        if let accessToken = accessToken {
            self.headers["Authorization"] = "Bearer " + accessToken
        } else {
            self.headers["Authorization"] = nil
        }
    }

    // MARK: - Core API

    /// Performs the login. Takes in an plain text email and password, matching the owner's login information for https://my.teslamotors.com/user/login. Returns a access_token which is passed along as a header with all future requests to authenticate the user.
    ///
    /// - Parameters:
    ///   - email: The email of the user
    ///   - password: The password of the user
    ///   - completion: Completion Handler
    open func getAccessToken(email: String, password: String, completion: @escaping (HTTPURLResponse, AccessToken.Response?, Error?) -> Void) {
        let request = AccessToken.Request(grantType: "password",
                                            clientId: self.configuration.clientId,
                                            clientSecret: self.configuration.clientSecret,
                                            email: email,
                                            password: password)        

        self.request(self.configuration.baseURL.appendingPathComponent("oauth/token"),
                     method: "POST",
                     parameters: request.toJSON(),
                     headers: self.headers,
                     completion: completion)
    }

    /// Request a new access token using a refresh token
    ///
    /// - Parameters:
    ///   - refreshToken: refreshToken from Tesla API
    ///   - completion: Completion handler callback
    open func getRefreshToken(_ refreshToken: String, completion: @escaping (HTTPURLResponse, RefreshToken.Response?, Error?) -> Void) {
        let request = RefreshToken.Request(grantType: "refresh_token",
                                            clientId: self.configuration.clientId,
                                            clientSecret: self.configuration.clientSecret,
                                            refreshToken: refreshToken)


        self.request(self.configuration.baseURL.appendingPathComponent("oauth/token"),
                     method: "POST",
                     parameters: request.toJSON(),
                     headers: self.headers,
                     completion: completion)
    }

    /// Logout and invalidate the current auth token
    ///
    /// - Parameter completion: Completion handler
    open func revokeAccessToken(completion: @escaping (HTTPURLResponse, AccessToken.Response?, Error?) -> Void) {
        self.request(self.configuration.baseURL.appendingPathComponent("oauth/revoke"),
                     method: "POST",
                     parameters: nil,
                     headers: self.headers,
                     completion: completion)
    }*/

    /// A logged in user can have multiple vehicles under their account. This resource is primarily responsible for listing the vehicles and the basic details about them.
    ///
    /// - Parameter completion: Completion Handler
    open func getVehicles(completion: @escaping (HTTPURLResponse, VehicleCollection?, Error?) -> Void) {
        self.request(self.configuration.apiBaseURL.appendingPathComponent("vehicles"),
                     method: "GET",
                     headers: self.headers,
                     completion: completion)
    }

    /// Get all data from the vehicle
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle to obtain data from
    ///   - completion: Completion Handler
    open func getData(_ vehicleId: String, completion: @escaping (HTTPURLResponse, Vehicle?, Error?) -> Void) {
        self.request(self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/vehicle_data"),
                     method: "GET",
                     headers: self.headers,
                     completion: completion)
    }
    
    /// Get near by chargers from the vehicle
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle to obtain data from
    ///   - completion: Completion Handler
    open func getNearbyChargers(_ vehicleId: String, completion: @escaping (HTTPURLResponse, Chargingsites?, Error?) -> Void) {
        self.request(self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/nearby_charging_sites"),
                     method: "GET",
                     headers: self.headers,
                     completion: completion)
    }

    /// Get some data from the vehicle
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle to obtain data from
    ///   - type: The type of data to request
    ///   - completion: Completion Handler
    @available(*, unavailable)
    open func getData<T: DataResponse>(_ vehicleId: String, type: DataRequest, completion: @escaping (HTTPURLResponse, T?, Error?) -> Void) {

        let url: URL = {
            switch type {
            case .mobileAccess: return self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/\(DataRequest.mobileAccess.rawValue)")
            case .data: return self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/\(DataRequest.data.rawValue)")
            default: return self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/data_request/\(type.rawValue)")
            }
        }()

        self.request(url,
                     method: "GET",
                     headers: self.headers,
                     completion: completion)
    }

    /// Send a command to the vehicle
    ///
    /// - Parameters:
    ///   - command: The command to be sent
    ///   - vehicleId: The id of the vehicle to send the command to
    ///   - request: Optional data to be included with the command
    ///   - completion: Completion Handler
    open func send(_ command: Command, to vehicleId: String, json: Any? = nil, completion: @escaping (CommandResponse) -> Void) {
        let url = self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/\(command.endpoint)")

        self.request(url,
                     method: "POST",
                     parameters: json,
                     headers: self.headers) { (httpResponse, dataOrNil: CommandResponse?, errorOrNil) in

                        var response = CommandResponse(result: true, reason: "")

                        defer {
                            self.delegate?.teslaApi(self, didSend: command, data: dataOrNil, result: response)
                            completion(response)
                        }

                        guard let data = dataOrNil, httpResponse.statusCode == 200 else {
                            response = CommandResponse(result: false, reason: errorOrNil?.localizedDescription ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                            return
                        }

                        guard data.result else {
                            response = CommandResponse(result: false, reason: data.error ?? data.reason ?? errorOrNil?.localizedDescription ?? "An error occurred")
                            return
                        }
        }
    }

    /// Send wake up command to vehicle
    open func wake(_ vehicleId: String, completion: @escaping (Bool, Vehicle?, String?) -> Void) {
        
        let url = self.configuration.apiBaseURL.appendingPathComponent("vehicles/\(vehicleId)/wake_up")

        self.request(url,
                     method: "POST",
                     parameters: nil,
                     headers: self.headers) { (response, dataOrNil: Vehicle?, errorOrNil) in

                        guard let data = dataOrNil, response.statusCode == 200 else {
                            completion(false, dataOrNil, errorOrNil?.localizedDescription ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
                            return
                        }

                        completion(true, data, nil)
        }
    }

    ///
    open func clearSession(completion: @escaping () -> Void) {
        let session = self.session
        session.invalidateAndCancel()
        session.reset {
            self.session = URLSession(configuration: .default)
            completion()
        }
    }

    /// Print the contents of URLRequest and HTTPURLResponse in a consistent format that is easy to inspect
    private func debugPrint(_ request: URLRequest, response: HTTPURLResponse, responseData: Data? = nil, error: Error? = nil) {
        var components: [String] = []

        let httpResponse = response
        let statusCode = httpResponse.statusCode

        // Method/URL
        if let url = request.url {
            components.append([request.httpMethod, url.absoluteString].compactMap{$0}.joined(separator: " "))
        }

        // Request Headers
        if let headers = request.allHTTPHeaderFields, headers.keys.count > 0 {
            let headersString: String = "RequestHeaders:\n" + headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            components.append(headersString)
        }

        // Request Data
        if let data = request.httpBody, let json = try? prettyPrint(json: data) {
            components.append("RequestBody:\n\(json)")
        }

        // Response Status
        let httpUrlResponseError = HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
        components.append("ResponseStatus: \(response.statusCode) \(httpUrlResponseError)")

        // Response Headers
        let responseHeaders = response.allHeaderFields
        if responseHeaders.keys.count > 0 {
            let headersString: String = "ResponseHeaders:\n" + responseHeaders.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            components.append(headersString)
        }

        // Response Data
        if let data = responseData, let json = try? prettyPrint(json: data) {
            components.append("ResponseBody:\n\(json)")
        }

        components.insert("", at: 0)
        components.append("")
        let logMessage = components.joined(separator: "\n")
        print(logMessage)
    }


    // MARK: - Convenience methods

    /// Send wake up command to vehicle
    open func wake(_ vehicle: Vehicle, completion: @escaping (Bool, Vehicle?, String?) -> Void) {
        self.wake(vehicle.id, completion: completion)
    }

    /// Request all data from vehicle
    open func getData(for vehicle: Vehicle, completion: @escaping (HTTPURLResponse, Vehicle?, Error?) -> Void) {
        self.getData(vehicle.id, completion: completion)
    }

    /// Send a command to the vehicle
    ///
    /// - Parameters:
    ///   - command: The command to be sent
    ///   - vehicle: The vehicle to send the command to
    ///   - request: Optional data to be included with the command
    ///   - completion: Completion Handler
    open func send(_ command: Command, to vehicle: Vehicle, parameters: BaseMappable? = nil, completion: @escaping (CommandResponse) -> Void) {
        self.send(command, to: vehicle.id, json: parameters?.toJSON(), completion: completion)
    }
    
    /// Request all nearby Chargers from vehicle
    open func getNearbyChargers(for vehicle: Vehicle, completion: @escaping (HTTPURLResponse, Chargingsites?, Error?) -> Void) {
        self.getNearbyChargers(vehicle.id, completion: completion)
    }
}


extension DispatchQueue {

    ///
    fileprivate func asyncAfter(seconds: Double, _ completion: @escaping ()->()) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            completion()
        }
    }
}

///
internal func prettyPrint(json data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data)
    let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    let string = String(data: data, encoding: String.Encoding.utf8)
    return string ?? ""
}


final public class WebCacheCleaner {
    
    public class func clean() {
        /* let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeCookies, WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
         let date = Date(timeIntervalSince1970: 0)
         WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler: {})*/
        UserDefaults.standard.removeObject(forKey: "teslatoken") 
        //teslaAPI.token = nil
        
        let storage = HTTPCookieStorage.shared
        storage.cookies?.forEach() {
            print("delete cooke: \($0)")
            storage.deleteCookie($0)
        }
        
        HTTPCookieStorage.shared.removeCookies(since: Date(timeIntervalSince1970: 0))
        print("[WebCacheCleaner] All cookies deleted")
        
        /*WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
        }*/
    }
    
}
