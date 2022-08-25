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
import UIKit
import SwiftUI

///
public protocol TeslaAPIDelegate: AnyObject {

    ///
    func teslaApiActivityDidBegin(_ teslaAPI: TeslaAPI)

    ///
    func teslaApiActivityDidEnd(_ teslaAPI: TeslaAPI, response: HTTPURLResponse, error: Error?)

    ///
    func teslaApi(_ teslaAPI: TeslaAPI, didSend command: Command, data: CommandResponse?, result: CommandResponse)
}

public enum TeslaError: Error, Equatable {
    case networkError(error: NSError)
    case authenticationRequired
    case authenticationFailed
    case tokenRevoked
    case noTokenToRefresh
    case tokenRefreshFailed
    case invalidOptionsForCommand
    case failedToParseData
    case failedToReloadVehicle
    case internalError
}

let ErrorInfo = "ErrorInfo"
private var nullBody = ""

open class TeslaAPI: NSObject, URLSessionDelegate {
    open var debuggingEnabled = true
	open var demoMode = false

    open fileprivate(set) var token: AuthToken?

    open fileprivate(set) var email: String?
    fileprivate var password: String?
	
	///
    public weak var delegate: TeslaAPIDelegate? = nil

    ///
    public var session: URLSession = URLSession(configuration: .default)

    public override init() { }
}


extension TeslaAPI {

	public var isAuthenticated: Bool {
        return token != nil && (token?.isValid ?? false)
    }
 
	/**
     Performs the authentition with the Tesla API for web logins

     For MFA users, this is the only way to authenticate.
     If the token expires, a token refresh will be done

     - parameter completion:      The completion handler when the token as been retrived
     - returns: A ViewController that your app needs to present. This ViewContoller will ask the user for his/her Tesla credentials, MFA code if set and then desmiss on successful authentication
     */
    #if canImport(WebKit) && canImport(UIKit)
    @available(iOS 13.0, *)
    public func authenticateWeb(completion: @escaping (Result<AuthToken, Error>) -> ()) -> TeslaWebLoginViewController? {
        let codeRequest = AuthCodeRequest()
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters

        guard let safeUrlComponents = urlComponents else { 
            completion(Result.failure(TeslaError.authenticationFailed))
            return TeslaWebLoginViewController(url: URL(string: "https://www.tesla.com")!)
        }

        let teslaWebLoginViewController = TeslaWebLoginViewController(url: safeUrlComponents.url!)

        teslaWebLoginViewController.result = { result in
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

        return teslaWebLoginViewController
    }
    #endif
    
    private func getAuthenticationTokenforWeb(code: String, completion: @escaping (Result<AuthToken, Error>) -> ()) {
        let body = AuthTokenRequestWeb(code: code)
        authRequest(.oAuth2Token, body: body) { [weak self] (result: Result<AuthToken, Error>) in
            switch result {
                case .success(let token):
                    self?.token = token
                    completion(Result.success(token))
                case .failure(let error):
                    if case let TeslaError.networkError(error: internalError) = error {
                        if internalError.code == 302 || internalError.code == 403 {
                            self?.authRequest(.oAuth2TokenCN, body: body) { (result2: Result<AuthToken, Error>) in
                                completion(result2)
                            }
                        } else if internalError.code == 401 {
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

        authRequest(.oAuth2Token, body: body) { (result: Result<AuthToken, Error>) in
            switch result {
                case .success(let token):
                    self.token = token
                    completion(Result.success(token))
                case .failure(let error):
                    if case let TeslaError.networkError(error: internalError) = error {
                        if internalError.code == 302 || internalError.code == 403 {
                            self.authRequest(.oAuth2TokenCN, body: body) { (result2: Result<AuthToken, Error>) in
                                completion(result2)
                            }
                        } else if internalError.code == 401 {
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
    Use this method to reuse a previous authentication token

    This method is useful if your app wants to ask the user for credentials once and reuse the token skipping authentication
    If the token is invalid a new authentication will be required

    - parameter token:      The previous token
    - parameter email:      Email is required for streaming
    */
    public func reuse(token: AuthToken, email: String? = nil) {
        self.token = token
        self.email = email
    }
    
    
    /**
     Revokes the stored token. Not working

     - returns: A completion handler with the token revoke state.
     */
    public func revokeWeb(completion: @escaping (Result<Bool, Error>) -> ()) -> Void {
        guard let accessToken = self.token?.accessToken else {
            cleanToken()
            completion(Result.success(false))
            return
        }

        checkAuthentication { (result: Result<AuthToken, Error>) in
            switch result {
                case .failure(let error):
                self.cleanToken()
                completion(Result.failure(error))
                case .success(_):
                self.cleanToken()
                    self.authRequest(.oAuth2revoke(token: accessToken), body: nullBody) { (result2: Result<BoolResponse, Error>) in
                        switch result2 {
                            case .failure(let error):
                                completion(Result.failure(error))
                            case .success(let data):
                                completion(Result.success(data.response))
                        }
                    }
            }
        }
    }
    
    /**
    Removes all the information related to the previous authentication
    
    */
    public func logout() {
        email = nil
        password = nil
        cleanToken()
        #if canImport(WebKit) && canImport(UIKit)
        TeslaWebLoginViewController.removeCookies()
        #endif
    }
    
    
    func checkToken() -> Bool {
        if let token = self.token {
            return token.isValid
        } else {
            return false
        }
    }
    
    func cleanToken() {
        token = nil
    }
    
    public func checkAuthentication(completion: @escaping (Result<AuthToken, Error>) -> ()) {
		if demoMode {
			completion(Result.success(AuthToken(accessToken: "DEMO")))
		} else {
			guard let token = self.token else { completion(Result.failure(TeslaError.authenticationRequired)); return }

			if checkToken() {
				completion(Result.success(token))
			} else {
				if token.refreshToken != nil {
					refreshWebToken() { (result: Result<AuthToken, Error>) in
						completion(result)
					}
				} else {
					completion(Result.failure(TeslaError.authenticationRequired))
				}
			}
		}
    }
}

extension TeslaAPI {
    /**
    Fetchs the list of your vehicles including not yet delivered ones
    
    - returns: An array of Vehicles.
    */
    public func getVehicles(completion: @escaping (Result<[String:Vehicle], Error>) -> ()) {
        checkAuthentication { (result: Result<AuthToken, Error>) in
            switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):
                if self.demoMode {
                    completion(Result.success(["VIN#DEMO":DemoTesla.shared.vehicle!]))
					} else {
                        self.vehicleRequest(.vehicles, body: nullBody) { (result2: Result<VehicleCollection?, Error>) in
							switch result2 {
                            case .failure(let error):
								completion(Result.failure(error))
                            case .success(let data):
                                var dict = [String:Vehicle]()
                                for element in data!.vehicles {
                                    dict[element.vin?.vinString ?? ""] = element
                                }
                                completion(Result.success(dict))
							}
						}
					}
            }
        }
    }
	
	/**
    Fetchs the vehicle according its method
    - methods e.g.: .vehicleSummary(vehicleID: vehicle.id!)
		.vehicleSummary(vehicleID: String)  	// vehicle from teslamotors.com, not the car itself
		.allStates(vehicleID: String)  			// complete vehicle infos from the car itself
		.chargeState(vehicleID: String)  		// specific vehicle dates form the car itself
		.climateState(vehicleID: String) 		// specific vehicle dates form the car itself
		.driveState(vehicleID: String) 			// specific vehicle dates form the car itself
    	.nearbyChargingSites(vehicleID: String) // specific vehicle dates form the car itself
		.guiSettings(vehicleID: String) 		// specific vehicle dates form the car itself
		.vehicleState(vehicleID: String) 		// specific vehicle dates form the car itself
		.vehicleConfig(vehicleID: String) 		// specific vehicle dates form the car itself
		.wakeUp(vehicleID: String)
    - returns: A Vehicle.
    */
    public func getVehicleData(_ method: Endpoint, completion: @escaping (Result<Vehicle?, Error>) -> ()) {
		checkAuthentication { (result: Result<AuthToken, Error>) in
			switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):
                    if self.demoMode {
						completion(Result.success(DemoTesla.shared.vehicle))
					} else {
						self.vehicleRequest(method, body: nullBody) { (result2: Result<Vehicle?, Error>) in
							switch result2 {
								case .failure(let error):
								completion(Result.failure(error))
								case .success(let vehicle):
									completion(Result.success(vehicle))
							}
						}
					}
            }
		}
    }
	
	/**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicleID: String, completion: @escaping (Result<Vehicle?, Error>) -> ()) {
        getVehicleData(.allStates(vehicleID: vehicleID)) { (result: Result<Vehicle?, Error>) in
			completion(result)
		}
    }
	
	/**
    Fetches the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicle: Vehicle, completion: @escaping (Result<Vehicle?, Error>) -> ()) {
        getVehicleData(.allStates(vehicleID: vehicle.id)) { (result: Result<Vehicle?, Error>) in
			completion(result)
		}
    }
	
	/**
     Fetches the vehicle data
     
     - returns: A completion handler with all the data
     */
    public func getAllData(_ vehicle: Vehicle, completion: @escaping (Result<Vehicle?, Error>) -> ()) {
		getVehicleData(.allStates(vehicleID: vehicle.id)) { (result: Result<Vehicle?, Error>) in
			completion(result)
		}
	}
	
	/**
	Fetches the vehicle mobile access state
	
	- returns: The mobile access state.
	*/
    public func getVehicleMobileAccessState(_ vehicle: Vehicle, completion: @escaping (Result<Bool, Error>) -> ()) {
		checkAuthentication { (result: Result<AuthToken, Error>) in
			switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):
                    if self.demoMode {
						completion(Result.success(true))
					} else {
                        self.vehicleRequest(.mobileAccess(vehicleID: vehicle.id), body: nullBody) { (result2: Result<Vehicle?, Error>) in
							switch result2 {
								case .failure(let error):
								completion(Result.failure(error))
								case .success(let data):
                                completion(Result.success((data != nil)))
							}
						}
					}
            }
		}
    }
    
    /**
     Fetches the nearby charging sites
     - parameter vehicle: the vehicle to get nearby charging sites from
     - returns: The nearby charging sites
     */
    public func getNearbyChargingSites(_ vehicle: Vehicle, completion: @escaping (Result<Chargingsites?, Error>) -> ()) {
        checkAuthentication { (result: Result<AuthToken, Error>) in
            switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):
                    self.vehicleRequest(.nearbyChargingSites(vehicleID: vehicle.id), body: nullBody) { (result2: Result<Chargingsites?, Error>) in
                        completion(result2)
                    }
            }
        }
    }
	
	/**
	Wakes up the vehicle
	
	- returns: The current Vehicle
	*/
    public func wakeUp(_ vehicle: Vehicle, completion: @escaping (Result<Bool, Error>) -> ()) {
		getVehicleData(.wakeUp(vehicleID: vehicle.id)) { (result: Result<Vehicle?, Error>) in
			switch result {
				case .failure(let error):
				completion(Result.failure(error))
				case .success(let data):
					// since vehicle is not fully wakeup just return true
					completion(Result.success(data != nil))
			}
		}
	}
    
}

extension TeslaAPI {
    func prepareRequest<BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil) -> URLRequest {
        var urlComponents = URLComponents(url: URL(string: endpoint.baseURL())!, resolvingAgainstBaseURL: true)
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = endpoint.method
        request.setValue("TesyCharging", forHTTPHeaderField: "User-Agent")

        if let token = self.token?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if debuggingEnabled {
            print("REQUEST: \(request)")
            print("METHOD: \(request.httpMethod!)")
            if let headers = request.allHTTPHeaderFields {
                var headersString = "REQUEST HEADERS: [\n"
                headers.forEach {(key: String, value: String) in
                    headersString += "\"\(key)\": \"\(value)\"\n"
                }
                headersString += "]"
                print(headersString)
            }
        }
    
        if let body = body as? String, body == nullBody {
        } else {
            request.httpBody = try? teslaJSONEncoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            if debuggingEnabled {
                print("body: \(body)")
            }
        }
        
        if let parameter = parameter {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameter)
        }
        
        return request
    }
            
            
	func authRequest<ReturnType: Decodable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil, completion: @escaping (Result<ReturnType, Error>) -> ()) -> Void {
		// Create the request
        let request = prepareRequest(endpoint, body: body)
        let debugEnabled = debuggingEnabled
		
        let task = self.session.dataTask(with: request) { (data, response, error) in
            let response: HTTPURLResponse = (response as? HTTPURLResponse) ?? HTTPURLResponse(url: URL(string: endpoint.baseURL())!, statusCode: 0, httpVersion: nil, headerFields: request.allHTTPHeaderFields!)!
            
			self.delegate?.teslaApiActivityDidEnd(self, response: response, error: error)
			
			guard error == nil else { completion(Result.failure(error!)); return }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(Result.failure(TeslaError.failedToParseData)); return }
			
			if debugEnabled {
				var responseString = "\nRESPONSE: \(String(describing: httpResponse.url))"
				responseString += "\nSTATUS CODE: \(httpResponse.statusCode)"
                if let headers = httpResponse.allHeaderFields as? [String: String] {
                    responseString += "\nHEADERS: [\n"
                    headers.forEach {(key: String, value: String) in
                        responseString += "\"\(key)\": \"\(value)\"\n"
                    }
                    responseString += "]"
                }
				print(responseString)
			}
            
            if case 200..<300 = httpResponse.statusCode {   
				// Attempt to serialize the response JSON and map to TeslaKit objects
				do {
                    if debugEnabled {
                        let objectString = String.init(data: data!, encoding: String.Encoding.utf8) ?? "No Body"
                        print("RESPONSE BODY: \(objectString)")
                    }
                    let mapped = try teslaJSONDecoder.decode(ReturnType.self, from: data!)
                    completion(Result.success(mapped))
				} catch let error {
                    print(error.localizedDescription)
					completion(Result.failure(TeslaError.failedToParseData))
				}
            } else {
				if debugEnabled {
					let objectString = String.init(data: data!, encoding: String.Encoding.utf8) ?? "No Body"
					print("RESPONSE BODY ERROR: \(objectString)")
				}
				if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
					wwwauthenticate.contains("invalid_token") {
					completion(Result.failure(TeslaError.tokenRevoked))
				} else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
					completion(Result.failure(TeslaError.authenticationFailed))
				} else if let mapped = try? teslaJSONDecoder.decode(ErrorMessage.self, from: data!) {
					completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:[ErrorInfo: mapped]))))
				} else {
					completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))))
				}
            }
		}
		self.delegate?.teslaApiActivityDidBegin(self)

        // Start the task immediately
		task.resume()
	}
            
    func vehicleRequest<T: Mappable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil, completion: @escaping (Result<T?, Error>) -> ()) -> Void {
        // Create the request
        let request = prepareRequest(endpoint, body: body)
        let debugEnabled = debuggingEnabled
        
        let task = self.session.dataTask(with: request) { (data, response, error) in
            let response: HTTPURLResponse = (response as? HTTPURLResponse) ?? HTTPURLResponse(url: URL(string: endpoint.baseURL())!, statusCode: 0, httpVersion: nil, headerFields: request.allHTTPHeaderFields!)!
            
            self.delegate?.teslaApiActivityDidEnd(self, response: response, error: error)
            
            guard error == nil else { completion(Result.failure(error!)); return }
            guard let httpResponse = response as? HTTPURLResponse else { completion(Result.failure(TeslaError.failedToParseData)); return }
            
            if debugEnabled {
                var responseString = "\nRESPONSE: \(String(describing: httpResponse.url))"
                responseString += "\nSTATUS CODE: \(httpResponse.statusCode)"
                if let headers = httpResponse.allHeaderFields as? [String: String] {
                    responseString += "\nHEADERS: [\n"
                    headers.forEach {(key: String, value: String) in
                        responseString += "\"\(key)\": \"\(value)\"\n"
                    }
                    responseString += "]"
                }
                print(responseString)
            }
            
            if case 200..<300 = httpResponse.statusCode {
                // Attempt to serialize the response JSON and map to TeslaKit objects
                do {
                    if let data = data {
                        let json: Any = try JSONSerialization.jsonObject(with: data)
                        let mappedVehicle = Mapper<T>().map(JSONObject: json)
                        if debugEnabled {
                            print("*********************")
                            var i = 0
                            var s = ""
                            while(i<data.count) {
                                s = s + String(UnicodeScalar(UInt8(data[i])))
                                i = i + 1
                            }
                            print(s)
                            print("*********************")
                        }
                        completion(Result.success(mappedVehicle))
                    }
                } catch let error {
                    print(error.localizedDescription)
                    completion(Result.failure(TeslaError.failedToParseData))
                }
            } else {
                if debugEnabled {
                    let objectString = String.init(data: data!, encoding: String.Encoding.utf8) ?? "No Body"
                    print("RESPONSE BODY ERROR: \(objectString)")
                }
                if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
                    wwwauthenticate.contains("invalid_token") {
                    completion(Result.failure(TeslaError.tokenRevoked))
                } else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
                    completion(Result.failure(TeslaError.authenticationFailed))
                } else if let mapped = try? teslaJSONDecoder.decode(ErrorMessage.self, from: data!) {
                    completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:[ErrorInfo: mapped]))))
                } else {
                    completion(Result.failure(TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))))
                }
            }
        }
        self.delegate?.teslaApiActivityDidBegin(self)

        // Start the task immediately
        task.resume()
    }
    

    
	/**
	Sends a command to the vehicle to set a paramter
	
	- parameter vehicle: the vehicle that will receive the command
	- parameter command: the command to send to the vehicle
	- parameter parameter: the value(s) that are set
	- returns: A completion handler with the CommandResponse object containing the results of the command.
	*/
	public func setCommand(_ vehicle: Vehicle, command: Command, parameter: Any? = nil, completion: @escaping (Result<CommandResponse?, Error>) -> Void) {
		checkAuthentication { (result: Result<AuthToken, Error>) in
			switch result {
                case .failure(let error):
                    completion(Result.failure(error))
                case .success(_):
                    if self.demoMode {
						//completion(Result.success(true))
					} else {
						self.vehicleRequest(.command(vehicleID: vehicle.id, command: command), body: nullBody, parameter: parameter) { (result2:Result<CommandResponse?, Error>) in
                            /*var response = CommandResponse(result: true, reason: "")
                            defer {
                                self.delegate?.teslaApi(self, didSend: command, data: dataOrNil, result: response)
                                completion(Result.success(respnse))
                            }*/
                            
							switch result2 {
								case .failure(let error):
								completion(Result.failure(error))
								case .success(let data):
                                completion(Result.success(data))
							}
						}
					}
            }
		}
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


public let teslaJSONEncoder: JSONEncoder = {
	let encoder = JSONEncoder()
	encoder.outputFormatting = .prettyPrinted
	encoder.dateEncodingStrategy = .secondsSince1970
	return encoder
}()

public let teslaJSONDecoder: JSONDecoder = {
	let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            if let dateDouble = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: dateDouble)
            } else {
                let dateString = try container.decode(String.self)
                let dateFormatter = ISO8601DateFormatter()
                var date = dateFormatter.date(from: dateString)
                guard let date = date else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                return date
            }
        })
	return decoder
}()

public struct WebLogin: UIViewControllerRepresentable {
    public typealias UIViewControllerType = TeslaWebLoginViewController
	public var teslaAPI: TeslaAPI
    public let action: () -> Void
    
    public init(teslaAPI: TeslaAPI, action: @escaping () -> Void) {
        self.teslaAPI = teslaAPI
        self.action = action
    }
	
    public func makeUIViewController(context: Context) -> TeslaWebLoginViewController {
        let webloginViewController = teslaAPI.authenticateWeb { (result: Result<AuthToken, Error>) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(_):
                self.action()
            }
        }
        return webloginViewController ?? TeslaWebLoginViewController(url: URL(string: "https://www.tesla.com")!)
    }

    public func updateUIViewController(_ uiViewController: TeslaWebLoginViewController, context: Context) {
    }
}
