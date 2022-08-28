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
    
    public var description: String {
        switch self {
        case .networkError(let error):
            return "Network Error: \(error)"
        case .authenticationRequired: return "Authentication Required"
        case .authenticationFailed: return "Authentication Failed"
        case .tokenRevoked: return "Token Revoked"
        case .noTokenToRefresh: return "No Token To Refresh"
        case .tokenRefreshFailed: return "Token Refresh Failed"
        case .invalidOptionsForCommand: return "Invalid Options For Command"
        case .failedToParseData: return "Failed To Parse Data"
        case .failedToReloadVehicle: return "Failed To Reload Vehicle"
        case .internalError: return "Internal Error"
        }
    }
}

let ErrorInfo = "ErrorInfo"
private var nullBody = ""

open class TeslaAPI: NSObject, URLSessionDelegate {
    open var debuggingEnabled = false
	open var demoMode = false
    open var addDemoVehicle = true

    open fileprivate(set) var token: AuthToken?

    open fileprivate(set) var email: String?
}


extension TeslaAPI {

	public var isAuthenticated: Bool {
        return demoMode ? true : (token != nil && (token?.isValid ?? false))
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
    public func authenticateWeb() -> (TeslaWebLoginViewController?, () async throws -> AuthToken) {
        let codeRequest = AuthCodeRequest()
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        
        guard let safeUrlComponents = urlComponents else {
            func error() async throws -> AuthToken {
                throw TeslaError.authenticationFailed
            }
            return (nil, error)
        }

        let teslaWebLoginViewController = TeslaWebLoginViewController(url: safeUrlComponents.url!)
        
        func result() async throws -> AuthToken {
           let url = try await teslaWebLoginViewController.result()
           let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
           if let queryItems = urlComponents?.queryItems {
               for queryItem in queryItems {
                   if queryItem.name == "code", let code = queryItem.value {
                       return try await self.getAuthenticationTokenForWeb(code: code)
                   }
               }
           }
           throw TeslaError.authenticationFailed
       }
       return (teslaWebLoginViewController, result)
    }
    #endif
    
    private func getAuthenticationTokenForWeb(code: String) async throws -> AuthToken {
        let body = AuthTokenRequestWeb(code: code)

        do {
            let token: AuthToken = try await authRequest(.oAuth2Token, body: body)
            self.token = token
            return token
        } catch let error {
            if case let TeslaError.networkError(error: internalError) = error {
                if internalError.code == 302 || internalError.code == 403 {
                    return try await self.authRequest(.oAuth2TokenCN, body: body)
                } else if internalError.code == 401 {
                    throw TeslaError.authenticationFailed
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /**
     Performs the token refresh with the Tesla API for Web logins

     - returns: A completion handler with the AuthToken.
     */
    public func refreshWebToken() async throws -> AuthToken {
        guard let token = self.token else { throw TeslaError.noTokenToRefresh }
        let body = AuthTokenRequestWeb(grantType: .refreshToken, refreshToken: token.refreshToken)

        do {
            let authToken: AuthToken = try await authRequest(.oAuth2Token, body: body)
            self.token = authToken
            return authToken
        } catch let error {
            if case let TeslaError.networkError(error: internalError) = error {
                if internalError.code == 302 || internalError.code == 403 {
                    //Handle redirection for tesla.cn
                    return try await self.authRequest(.oAuth2TokenCN, body: body)
                } else if internalError.code == 401 {
                    throw TeslaError.tokenRefreshFailed
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    public func refreshMyWebToken() throws -> AuthToken {
        var token: AuthToken = AuthToken(accessToken: "")

        Task { @MainActor in
            do {
                token = try await refreshWebToken()
            } catch let error {
                print("refresh web token failed: \(error)")
                throw error
            }
        }
        return token
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
    public func revokeWeb() async throws -> Bool {
        guard let accessToken = self.token?.accessToken else {
            cleanToken()
            return false
        }

        _ = try await checkAuthentication()
        self.cleanToken()

        let response: BoolResponse = try await authRequest(.oAuth2revoke(token: accessToken), body: nullBody)
        return response.response
    }
    
    /**
    Removes all the information related to the previous authentication
    
    */
    public func logout() {
        //email = nil
        cleanToken()
        #if canImport(WebKit) && canImport(UIKit)
        TeslaWebLoginViewController.removeCookies()
        #endif
    }
       
    func cleanToken() {
        token = nil
    }
    
    func checkAuthentication() async throws -> AuthToken {
        if self.demoMode {
            return AuthToken(accessToken: "demo")
        } else {
            guard let token = self.token else { throw TeslaError.authenticationRequired }
        
            if self.isAuthenticated {
                return token
            } else {
                if token.refreshToken != nil {
                    return try await refreshWebToken()
                } else {
                    throw TeslaError.authenticationRequired
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
    public func getVehicles() async throws -> [String:Vehicle] {
        _ = try await checkAuthentication()
        if self.demoMode {
            return ["VIN#DEMO_#TESTING":DemoTesla.shared.vehicle!]
        } else {
            let response: VehicleCollection = try await vehicleRequest(.vehicles, body: nullBody)
            var dict = [String:Vehicle]()
            for element in response.vehicles {
                dict[element.vin?.vinString ?? ""] = element
            }
            if self.addDemoVehicle {
                dict["VIN#DEMO_#TESTING"] = DemoTesla.shared.vehicle!
            }
            return dict
        }
    }
    
    public func getMyVehicles() throws -> [String:Vehicle] {
        var vehicles: [String:Vehicle] = [String:Vehicle]()

        Task { @MainActor in
            do {
                vehicles = try await getVehicles()
            } catch let error {
                print("Authentication failed: \(error)")
                throw error
            }
        }
        return vehicles
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
    public func getVehicleData(_ method: Endpoint) async throws -> Vehicle {
        _ = try await checkAuthentication()
        if self.demoMode {
            switch method {
            case .allStates(_), .vehicleSummary(_):
                return (DemoTesla.shared.vehicle)!
                /*case .chargeState(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.chargeState as? T))
                 case .climateState(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.climateState as? T))
                 case .driveState(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.driveState as? T))
                 case .guiSettings(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.guiSettings as? T))
                 case .vehicleState(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.vehicleState as? T))
                 case .vehicleConfig(_):
                 completion(Result.success(DemoTesla.shared.vehicle?.vehicleConfig as? T))*/
            default:
                throw TeslaError.failedToParseData
            }
        } else {
            let response: Vehicle = try await vehicleRequest(.vehicles, body: nullBody)
            return response
        }
    }
    
	
	/**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicleID: String) async throws -> Vehicle {
        return try await getVehicleData(.allStates(vehicleID: vehicleID))
    }
	
	/**
    Fetches the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING")
        return try await getVehicleData(.allStates(vehicleID: vehicle.id))
    }
	
	/**
     Fetches the vehicle data
     
     - returns: A completion handler with all the data
     */
    public func getAllData(_ vehicle: Vehicle) async throws -> Vehicle {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING")
		return try await getVehicleData(.allStates(vehicleID: vehicle.id))
	}
	
	/**
	Fetches the vehicle mobile access state
	
	- returns: The mobile access state.
	*/
    public func getVehicleMobileAccessState(_ vehicle: Vehicle) async throws -> Bool {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING")
        if demoMode {
            return true
        } else {
            _ = try await checkAuthentication()
            let response: Vehicle = try await self.vehicleRequest(.mobileAccess(vehicleID: vehicle.id), body: nullBody)
            return response != nil
        }
    }
    
    /**
     Fetches the nearby charging sites
     - parameter vehicle: the vehicle to get nearby charging sites from
     - returns: The nearby charging sites
     */
    public func getNearbyChargingSites(_ vehicle: Vehicle) async throws -> Chargingsites {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING")
        if demoMode {
            var sites = Chargingsites()
            var dest = DestinationCharging()
            dest.name = "Charger Zuoz"
            dest.location.lat = 46.60397488081502
            dest.location.long = 9.957636562225217
            dest.distance_miles = 15
            sites.destination_charging = [dest]
            var supercharger = Superchargers()
            supercharger.name = "Tesla Supercharger Parkhaus"
            supercharger.location.lat = 46.49699
            supercharger.location.long = 9.84191
            supercharger.distance_miles = 0
            supercharger.available_stalls = 5
            supercharger.total_stalls = 8
            sites.superchargers = [supercharger]
            return sites
        } else {
            _ = try await checkAuthentication()
            let response: Chargingsites = try await self.vehicleRequest(.nearbyChargingSites(vehicleID: vehicle.id), body: nullBody)
            return response
        }
    }
	
	/**
	Wakes up the vehicle
	
	- returns: The current Vehicle
	*/
    public func wakeUp(_ vehicle: Vehicle) async throws -> Bool {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING") 
        if demoMode {
            return true
        } else {
            _ = try await checkAuthentication()
            let response: Vehicle = try await self.vehicleRequest(.wakeUp(vehicleID: vehicle.id), body: nullBody)
            return response != nil
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
            print(request.httpBody)
            print(request)
        }
        
        return request
    }
            
        
    private func authRequest<ReturnType: Decodable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType) async throws -> ReturnType {
		// Create the request
        let request = prepareRequest(endpoint, body: body)
        let debugEnabled = debuggingEnabled
        
        let data: Data
        let response: URLResponse

        if #available(iOS 15.0, *) {
            (data, response) = try await URLSession.shared.data(for: request)
        } else {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let data = data, let response = response {
                        continuation.resume(with: .success((data, response)))
                    } else {
                        continuation.resume(with: .failure(error ?? TeslaError.internalError))
                    }
                }
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { throw TeslaError.failedToParseData }
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
                    let objectString = String.init(data: data, encoding: String.Encoding.utf8) ?? "No Body"
                    print("RESPONSE BODY: \(objectString)")
                }
                let mapped = try teslaJSONDecoder.decode(ReturnType.self, from: data)
                return mapped
            } catch let error {
                print(error.localizedDescription)
                throw TeslaError.failedToParseData
            }
        } else {
            if debugEnabled {
                let objectString = String.init(data: data, encoding: String.Encoding.utf8) ?? "No Body"
                print("RESPONSE BODY ERROR: \(objectString)")
            }
            if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
                wwwauthenticate.contains("invalid_token") {
                throw TeslaError.tokenRevoked
            } else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
                throw TeslaError.authenticationFailed
            } else if let mapped = try? teslaJSONDecoder.decode(ErrorMessage.self, from: data) {
                throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:[ErrorInfo: mapped]))
            } else {
                throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))
            }
        }
	}
    
    private func vehicleRequest<T: Mappable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil) async throws -> T {
        // Create the request
        let request = prepareRequest(endpoint, body: body, parameter: parameter)
        let debugEnabled = debuggingEnabled
        
        let data: Data
        let response: URLResponse
        
        if #available(iOS 15.0, *) {
            (data, response) = try await URLSession.shared.data(for: request)
        } else {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let data = data, let response = response {
                        continuation.resume(with: .success((data, response)))
                    } else {
                        continuation.resume(with: .failure(error ?? TeslaError.internalError))
                    }
                }
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { throw TeslaError.failedToParseData }
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
            do {
                let json: Any = try JSONSerialization.jsonObject(with: data)
                guard let mappedVehicle = Mapper<T>().map(JSONObject: json) else {
                    throw TeslaError.failedToParseData
                }
                return mappedVehicle
            } catch let error {
                print(error.localizedDescription)
                throw TeslaError.failedToParseData
            }
        } else {
            if debugEnabled {
                let objectString = String.init(data: data, encoding: String.Encoding.utf8) ?? "No Body"
                print("RESPONSE BODY ERROR: \(objectString)")
            }
            if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
                wwwauthenticate.contains("invalid_token") {
                throw TeslaError.tokenRevoked
            } else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
                throw TeslaError.authenticationFailed
            } else if let mapped = try? teslaJSONDecoder.decode(ErrorMessage.self, from: data) {
                throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:[ErrorInfo: mapped]))
            } else {
                throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: nil))
            }
        }
    }
    

    
	/**
	Sends a command to the vehicle to set a paramter
	
	- parameter vehicle: the vehicle that will receive the command
	- parameter command: the command to send to the vehicle
	- parameter parameter: the value(s) that are set
	- returns: A completion handler with the CommandResponse object containing the results of the command.
	*/
    public func setCommand(_ vehicle: Vehicle, command: Command, parameter: Any? = nil) async throws -> CommandResponse {
        self.demoMode = (vehicle.vin?.vinString == "VIN#DEMO_#TESTING")
        if self.demoMode {
            var response = CommandResponse(result: true, reason: "")
            switch command {
            case .setValetMode:
                DemoTesla.shared.vehicle?.vehicleState.valetMode.toggle()
            case .resetValetPin:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .openChargePort:
                DemoTesla.shared.engageCable()
            case .closeChargePort:
                DemoTesla.shared.vehicle?.chargeState.chargePortDoorOpen = false
            case .setChargeLimitToStandard:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSocStd = Int((parameter as! SetChargeLimit).limitValue)
            case .setChargeLimitToMaxRange:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSocMax = Int((parameter as! SetChargeLimit).limitValue)
            case .setChargeLimit:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSoc = Int((parameter as! SetChargeLimit).limitValue)
            case .startCharging:
                DemoTesla.shared.startCharging()
            case .stopCharging:
                DemoTesla.shared.stopCharging()
            case .flashLights, .honkHorn:
                print("Command: \(command.description)")
                response.reason = "succesful \(command.description)"
            case .unlockDoors:
                DemoTesla.shared.vehicle?.vehicleState.locked = false
            case .lockDoors:
                DemoTesla.shared.vehicle?.vehicleState.locked = true
            case .setTemperature:
                DemoTesla.shared.vehicle?.climateState.driverTemperatureSetting = (parameter as! SetTemperature).driverTemp
                DemoTesla.shared.vehicle?.climateState.passengerTemperatureSetting = (parameter as! SetTemperature).passengerTemp
            case .startHVAC:
                DemoTesla.shared.vehicle?.climateState.isClimateOn = true
            case .stopHVAC:
                DemoTesla.shared.vehicle?.climateState.isClimateOn = false
            case .movePanoRoof:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .remoteStart:
                DemoTesla.shared.vehicle?.vehicleState.remoteStart.toggle()
            case .openTrunk:
                let r = ((DemoTesla.shared.vehicle?.vehicleState.rearTrunkState ?? 0) + 1) % 2
                DemoTesla.shared.vehicle?.vehicleState.rearTrunkState = r
            case .setPreconditioningMax, .speedLimitActivate, .speedLimitDeactivate, .speedLimitClearPIN, .setSpeedLimit:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .togglePlayback, .nextTrack, .previousTrack, .nextFavorite, .previousFavorite, .volumeUp, .volumeDown:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .navigationRequest:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .scheduleSoftwareUpdate, .cancelSoftwareUpdate:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .remoteSeatHeater, .remoteSteeringWheelHeater:
                print("Command \(command.description) not implemented")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .sentryMode:
                DemoTesla.shared.vehicle?.vehicleState.sentryMode = (parameter as! SentryMode).isOn
            case .homelink:
                if ((DemoTesla.shared.vehicle?.vehicleState.homelinkNearby) != nil)  && ((DemoTesla.shared.vehicle?.driveState.nativeLatitude == (parameter as! TriggerHomelink).lat) && (
                    DemoTesla.shared.vehicle?.driveState.nativeLongitude == (parameter as! TriggerHomelink).lon)) {
                    print("Command: \(command.description)")
                    response.reason = "succesful \(command.description)"
                } else {
                    response.result = false
                    response.reason = "no homelink nearby or lat/lon not nearby"
                    print("no homelink nearby or lat/lon not nearby")
                }
            case .openWindow:
                if (parameter as? WindowsControl)?.lat == DemoTesla.shared.vehicle?.driveState.nativeLatitude && (parameter as? WindowsControl)?.lon == DemoTesla.shared.vehicle?.driveState.nativeLongitude {
                    let windowOpen = ((parameter as? WindowsControl)?.command != .close) ? 1 : 0
                    DemoTesla.shared.vehicle?.vehicleState.fd_window = windowOpen
                    DemoTesla.shared.vehicle?.vehicleState.fp_window = windowOpen
                    DemoTesla.shared.vehicle?.vehicleState.rd_window = windowOpen
                    DemoTesla.shared.vehicle?.vehicleState.rp_window = windowOpen
                } else {
                    response.result = false
                    response.reason = "lat/lon not nearby"
                    print("lat/lon not nearby")
                }
            }
            return response
        } else {
            _ = try await checkAuthentication()
            let response: CommandResponse = try await self.vehicleRequest(.command(vehicleID: vehicle.id, command: command), body: nullBody, parameter: parameter)
            return response
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
        let (webloginViewController, result) = teslaAPI.authenticateWeb()
        guard let safeWebloginViewController = webloginViewController else {
            return TeslaWebLoginViewController(url: URL(string: "https://www.tesla.com")!)
        }
        
        Task { @MainActor in
            do {
                _ = try await result()
                self.action()
            } catch let error {
                print("Authentication failed: \(error)")
            }
        }
        return safeWebloginViewController
        
    }

    public func updateUIViewController(_ uiViewController: TeslaWebLoginViewController, context: Context) {
    }
}
