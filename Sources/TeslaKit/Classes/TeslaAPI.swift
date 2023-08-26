//
//  TeslaAPI.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/19/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import WebKit
import Combine
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import os



public enum TeslaError: Error, Equatable {
    case networkError(error: NSError)
    case authenticationRequired
    case authenticationFailed(msg: String)
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

private var nullBody = ""

open class TeslaAPI: NSObject, URLSessionDelegate {
    open var debuggingEnabled = false
	open var demoMode = false
    open var addDemoVehicle = true

    open fileprivate(set) var token: AuthToken?
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: TeslaAPI.self))
}


@available(macOS 13.1, *)
extension TeslaAPI {

	public var isAuthenticated: Bool {
        return demoMode ? true : (token != nil && (token?.isValid ?? false))
    }
 
	/**
     Performs the authentition with the Tesla API for web logins

     For MFA users, this is the only way to authenticate.
     If the token expires, a token refresh will be done

     - returns: A ViewController that your app needs to present. This ViewContoller will ask the user for his/her Tesla credentials, MFA code if set and then desmiss on successful authentication
	 An async function that returns when the token as been retrieved
     */
    //#if canImport(WebKit) && canImport(UIKit)
    public func authenticateWeb() -> (TeslaWebLoginViewController?, () async throws -> AuthToken) {
        let codeRequest = AuthCodeRequest()
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        
        guard let safeUrlComponents = urlComponents else {
            func error() async throws -> AuthToken {
                throw TeslaError.authenticationFailed(msg: "")
            }
            return (nil, error)
        }
        let teslaWebLoginViewController = TeslaWebLoginViewController(url: safeUrlComponents.url!)
        
        func result() async throws -> AuthToken {
            let url = try await teslaWebLoginViewController.result()
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            if let queryItems = urlComponents?.queryItems, let code = queryItems.first(where: { $0.name == "code" })?.value, let state = queryItems.first(where: { $0.name == "state" }) {
                if "\(state)" == "state=\(codeRequest.state)" {
                    return try await self.getAuthenticationTokenForWeb(codeRequest.codeVerifier, code: code)
                } else {
                    throw TeslaError.authenticationFailed(msg: "state is different in callback")
                }
            }
            throw TeslaError.authenticationFailed(msg: "no code parameter in callback")
       }
       return (teslaWebLoginViewController, result)
    }
    //#endif
    
    private func getAuthenticationTokenForWeb(_ codeVerifier: String = "", code: String) async throws -> AuthToken {
        let body = AuthTokenRequestWeb(codeVerifier, code: code)

        do {
            let token: AuthToken = try await request(.oAuth2Token, body: body)
            self.token = token
            return token
        } catch let error {
            if case let TeslaError.networkError(error: internalError) = error {
                if internalError.code == 302 || internalError.code == 403 {
                    return try await self.request(.oAuth2TokenCN, body: body)
                } else if internalError.code == 401 {
                    throw TeslaError.authenticationFailed(msg: "")
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    @available(macOS 13.1, *)
    public func getAuthenticationTokenForWeb(_ codeVerifier: String = "", code: String, completion: @escaping(Result<AuthToken, Error>) -> Void) {
        Task { @MainActor in
            do {
                let token: AuthToken = try await getAuthenticationTokenForWeb(codeVerifier, code: code)
                completion(Result.success(token))
            } catch let error {
                completion(Result.failure(error))
            }
        }
    }
    
    /**
     Performs the token refresh with the Tesla API for Web logins

     - returns: The AuthToken.
	 An async function that returns when the token as been requested
     */
    public func refreshWebToken() async throws -> AuthToken {
        guard let token = self.token else { throw TeslaError.noTokenToRefresh }
        let body = AuthTokenRequestWeb(grantType: .refreshToken, refreshToken: token.refreshToken)

        do {
            let authToken: AuthToken = try await request(.oAuth2Token, body: body)
            self.token = authToken
            return authToken
        } catch let error {
            if case let TeslaError.networkError(error: internalError) = error {
                if internalError.code == 302 || internalError.code == 403 {
                    //Handle redirection for tesla.cn
                    return try await self.request(.oAuth2TokenCN, body: body)
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
    
  
    /**
    Use this method to reuse a previous authentication token

    This method is useful if your app wants to ask the user for credentials once and reuse the token skipping authentication
    If the token is invalid a new authentication will be required

    - parameter token:      The previous token
    */
    public func reuse(token: AuthToken) {
        self.token = token
    }
    
    
    /**
     Revokes the stored token. 

     - returns: The token revoke state.
	 An async function that returns true when the token as been revoked
     */
    public func revokeWeb() async throws -> Bool {
        guard let accessToken = self.token?.accessToken else {
            token = nil
            return false
        }

        _ = try await checkAuthentication()
        token = nil

        let response: BoolResponse = try await request(.oAuth2revoke(token: accessToken), body: nullBody)
        return response.response
    }
    
    /**
    Removes all the information related to the previous authentication
    
    */
    public func logout() {
        token = nil
        #if canImport(WebKit) && canImport(UIKit)
        TeslaWebLoginViewController.removeCookies()
        #endif
    }
    
	/**
    Checks if the authenication is valid and refreshes the token if required
     
	An async function that throws an error if authentication doesn't exist
    */
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

@available(macOS 13.1, *)
extension TeslaAPI {
  /**
  Fetches the user of the Tesla Account

  - returns email, fullname and url to profile image
  */
  public func getUser() async throws -> User? {
	  return try await getVehicleData(.user)
  }
	
    /**
    Fetchs the list of your vehicles including not yet delivered ones
    
    - returns: An array of [String:Vehicle], VinNumber: Vehicle
    */
    public func getVehicles() async throws -> [String:Vehicle] {
        _ = try await checkAuthentication()
        if self.demoMode {
            return ["VIN#DEMO_#TESTING":DemoTesla.shared.vehicle!]
        } else {
			let response: VehicleCollection = try await request(.vehicles, body: nullBody)
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
    - returns: A child type of the protocol DataResponse.
    */
    public func getVehicleData<T: DataResponse>(_ method: Endpoint, demoMode: Bool = false) async throws -> T? {
        _ = try await checkAuthentication()
        if self.demoMode  || demoMode {
            switch method {
            case .vehicles:
                return ([DemoTesla.shared.vehicle!] as! T)
            case .allStates(_), .vehicleSummary(_):
                return ((DemoTesla.shared.vehicle)! as! T)
            case .chargeState(_):
                return (DemoTesla.shared.vehicle!.chargeState as! T)
            case .climateState(_):
                return (DemoTesla.shared.vehicle!.climateState as! T)
            case .driveState(_):
                return (DemoTesla.shared.vehicle!.driveState as! T)
            case .guiSettings(_):
                return (DemoTesla.shared.vehicle!.guiSettings as! T)
            case .vehicleState(_):
                return (DemoTesla.shared.vehicle!.vehicleState as! T)
            case .vehicleConfig(_):
                return (DemoTesla.shared.vehicle!.vehicleConfig as! T)
            case . user:
                return (DemoTesla.shared.user as! T)
            default:
                throw TeslaError.failedToParseData
            }
        } else {
            let response = try await self.request(method, body: nullBody) as T
            return response
        }
    }
    
	
	/**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicleID: String) async throws -> Vehicle? {
        return try await getVehicleData(.allStates(vehicleID: vehicleID))
    }
	
	/**
    Fetches the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicle(_ vehicle: Vehicle) async throws -> Vehicle? {
        return try await getVehicleData(.allStates(vehicleID: vehicle.id), demoMode: (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"))
    }
	
	/**
     Fetches the vehicle data
     
     - returns: A completion handler with all the data
     */
    public func getAllData(_ vehicle: Vehicle) async throws -> Vehicle? {
		return try await getVehicleData(.allStates(vehicleID: vehicle.id), demoMode: (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"))
	}
	
	/**
	Fetches the vehicle mobile access state. The vehicle has to be awake (online)
	
	- returns: The mobile access state.
	*/
    public func getVehicleMobileAccessState(_ vehicle: Vehicle) async throws -> Bool {
        if demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            return true
        } else {
            _ = try await checkAuthentication()
            let response: MobileAccess = try await self.request(Endpoint.mobileAccess(vehicleID: vehicle.id), body: nullBody)
            return response.response
        }
    }
    
    /**
     Fetches the nearby charging sites
     - parameter vehicle: the vehicle to get nearby charging sites from
     - returns: The nearby charging sites
     */
    public func getNearbyChargingSites(_ vehicle: Vehicle) async throws -> Chargingsites {
        if demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
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
            let response: Chargingsites = try await self.request(Endpoint.nearbyChargingSites(vehicleID: vehicle.id), body: nullBody)
            return response
        }
    }
	
	/**
	Wakes up the vehicle
	
	- returns: always true. It takes a while (~30 seconds) after return till the vehicle is online
	*/
    public func wakeUp(_ vehicle: Vehicle) async throws -> Bool {
        if demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            return true
        } else {
            _ = try await checkAuthentication()
            _ = try await self.request(Endpoint.wakeUp(vehicleID: vehicle.id), body: nullBody) as Vehicle
            return true
        }
	}
    
}

@available(macOS 13.1, *)
extension TeslaAPI {
    func prepareRequest<BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil) -> URLRequest {
        var urlComponents = URLComponents(url: URL(string: endpoint.baseURL())!, resolvingAgainstBaseURL: true)
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = endpoint.method
        //request.setValue("curl / 6.14.0", forHTTPHeaderField: "User-Agent")

        if let token = self.token?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    
        if let body = body as? String, body == nullBody {
        } else {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			encoder.dateEncodingStrategy = .secondsSince1970
            request.httpBody = try? encoder.encode(body)
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "content-type")
        }
        
        if let parameter = parameter {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.setValue("no-cache", forHTTPHeaderField: "cache-control")
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameter)
        }
        
        return request
    }
            
	
    public func request<T: Mappable, BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType, parameter: Any? = nil) async throws -> T {
        // Create the request
        let request = prepareRequest(endpoint, body: body, parameter: parameter)
        let debugEnabled = debuggingEnabled
        if debugEnabled {
            TeslaAPI.logger.debug("url: \(request.url!), privacy: .public)")
            TeslaAPI.logger.debug("method: \(request.httpMethod ?? ""), privacy: .public)")
            if let allHTTPHeaderFields = request.allHTTPHeaderFields {
                TeslaAPI.logger.debug("httpHeader: \(allHTTPHeaderFields), privacy: .public)")
            }
            if let httpBody = request.httpBody {
                TeslaAPI.logger.debug("httpBody: \(String(data: httpBody, encoding: .utf8)!), privacy: .public)")
            }
        }
        
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
            TeslaAPI.logger.debug("RESPONSE: \(httpResponse.url!), privacy: .public)")
            TeslaAPI.logger.debug("STATUS CODE: \(httpResponse.statusCode), privacy: .public)")
            TeslaAPI.logger.debug("HEADERS: \(httpResponse.allHeaderFields), privacy: .public)")
            TeslaAPI.logger.debug("DATA: \(String(data: data, encoding: .utf8) ?? ""), privacy: .public)")
        }
        
        if case 200..<300 = httpResponse.statusCode {
            // Attempt to serialize the response JSON and map to TeslaKit objects
            do {
                let json: Any = try JSONSerialization.jsonObject(with: data)
                guard let mappedVehicle = Mapper<T>().map(JSONObject: json) else {
                    throw TeslaError.failedToParseData
                }
                return mappedVehicle
            } catch let error {
                TeslaAPI.logger.debug("\(error.localizedDescription), privacy: .public)")
                throw TeslaError.failedToParseData
            }
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 400{
            throw TeslaError.authenticationFailed(msg: String(data: data, encoding: .utf8) ?? "")
        } else {
            if debugEnabled {
                let objectString = String.init(data: data, encoding: String.Encoding.utf8) ?? "No Body"
                TeslaAPI.logger.debug("RESPONSE BODY ERROR: \(objectString), privacy: .public)")
            }
            if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
               wwwauthenticate.contains("invalid_token") {
                throw TeslaError.tokenRevoked
            } else if httpResponse.allHeaderFields["Www-Authenticate"] != nil, httpResponse.statusCode == 401 {
                throw TeslaError.authenticationFailed(msg: String(data: data, encoding: .utf8) ?? "")
            } else {
                let json: Any = try JSONSerialization.jsonObject(with: data)
                guard let mappedVehicle = Mapper<T>().map(JSONObject: json) else {
                    throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo: ["ErrorInfo": TeslaError.failedToParseData]))
                }
                throw TeslaError.networkError(error: NSError(domain: "TeslaError", code: httpResponse.statusCode, userInfo:["ErrorInfo": mappedVehicle]))
            }
        }
    }

    
	/**
	Sends a command to the vehicle to set a paramter
	
	- parameter vehicle: the vehicle that will receive the command
	- parameter command: the command to send to the vehicle
	- parameter parameter: the value(s) that are set
	- returns: CommandResponse
	*/
    public func setCommand(_ vehicle: Vehicle, command: Command, parameter: BaseMappable? = nil) async throws -> CommandResponse {
        if self.demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            var response = CommandResponse(result: true, reason: "")
            switch command {
            case .setValetMode:
                DemoTesla.shared.vehicle?.vehicleState.valetMode.toggle()
            case .resetValetPin:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .openChargePort:
                if !(DemoTesla.shared.vehicle?.chargeState.chargePortDoorOpen ?? false) {
                    //open
                    DemoTesla.shared.vehicle?.chargeState.chargePortDoorOpen = true
                    //plug it after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+5.0) {
                        DemoTesla.shared.plug_unplug()
                    }
                } else if (DemoTesla.shared.vehicle?.chargeState.chargingState == .stopped || DemoTesla.shared.vehicle?.chargeState.chargingState == .complete) &&  DemoTesla.shared.vehicle?.chargeState.chargingState != .charging {
                    //disengage it
                    DemoTesla.shared.vehicle?.chargeState.chargePortLatch = .disengaged
                    //re-engage after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+10.0) {
                        if (DemoTesla.shared.vehicle?.chargeState.chargePortDoorOpen ?? false) && DemoTesla.shared.vehicle?.chargeState.chargePortLatch == .disengaged && DemoTesla.shared.vehicle?.chargeState.chargingState != .disconnected {
                            DemoTesla.shared.vehicle?.chargeState.chargePortLatch = .engaged
                        }
                    }
                } else {
                    response.result = false
                    response.reason = "Command \(command.description) error"
                } 
            case .closeChargePort:
                if DemoTesla.shared.vehicle?.chargeState.chargingState == .disconnected {
                    DemoTesla.shared.vehicle?.chargeState.chargePortDoorOpen = false
                } else {
                    response.result = false
                    response.reason = "Command \(command.description) error"
                }
            case .setChargeLimitToStandard:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSocStd = Int((parameter as! SetChargeLimit).limitValue)
            case .setChargeLimitToMaxRange:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSocMax = Int((parameter as! SetChargeLimit).limitValue)
            case .setChargeLimit:
                DemoTesla.shared.vehicle?.chargeState.chargeLimitSoc = Int((parameter as! SetChargeLimit).limitValue)
            case .startCharging:
                if (DemoTesla.shared.vehicle?.chargeState.chargeLimitSoc ?? 0) <= (DemoTesla.shared.vehicle?.chargeState.usableBatteryLevel ?? 0){
                    DemoTesla.shared.vehicle?.chargeState.chargingState = ChargingState.complete
                } else {
                    DemoTesla.shared.vehicle?.chargeState.chargingState = ChargingState.charging
                    DemoTesla.shared.charging()
                }
            case .stopCharging:
                if DemoTesla.shared.vehicle?.chargeState.chargingState == .charging {
                    DemoTesla.shared.vehicle?.chargeState.chargingState = ChargingState.stopped
                } else {
                    response.result = false
                    response.reason = "Command \(command.description) error"
                }
            case .flashLights, .honkHorn:
                TeslaAPI.logger.debug("Command: \(command.description), privacy: .public)")
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
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .remoteStart:
                DemoTesla.shared.vehicle?.vehicleState.remoteStart.toggle()
            case .openTrunk:
                if (parameter as! OpenTrunk).trunkType == .front {
                    let f = ((DemoTesla.shared.vehicle?.vehicleState.frontTrunkState ?? 0) + 1) % 2
                    DemoTesla.shared.vehicle?.vehicleState.frontTrunkState = f
                } else {
                    let r = ((DemoTesla.shared.vehicle?.vehicleState.rearTrunkState ?? 0) + 1) % 2
                    DemoTesla.shared.vehicle?.vehicleState.rearTrunkState = r
                }
            case .setPreconditioningMax:
                if (parameter as! SetPreconditioningMax).isOn {
                    DemoTesla.shared.vehicle?.climateState.defrostMode = 1
                    DemoTesla.shared.vehicle?.climateState.isFrontDefrosterOn = true
                    DemoTesla.shared.vehicle?.climateState.isRearDefrosterOn = true
                    DemoTesla.shared.vehicle?.climateState.seatHeaterLeft = 3
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRight = 3
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearLeft = 3
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearCenter = 3
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearRight = 3
                } else {
                    DemoTesla.shared.vehicle?.climateState.defrostMode = 0
                    DemoTesla.shared.vehicle?.climateState.isFrontDefrosterOn = false
                    DemoTesla.shared.vehicle?.climateState.isRearDefrosterOn = false
                    DemoTesla.shared.vehicle?.climateState.seatHeaterLeft = 0
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRight = 0
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearLeft = 0
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearCenter = 0
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearRight = 0
                    DemoTesla.shared.vehicle?.climateState.isClimateOn = false
                }
            case .speedLimitActivate, .speedLimitDeactivate, .speedLimitClearPIN, .setSpeedLimit:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .togglePlayback, .nextTrack, .previousTrack, .nextFavorite, .previousFavorite, .volumeUp, .volumeDown:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .navigationRequest:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented, use share instead"
            case .scheduleSoftwareUpdate, .cancelSoftwareUpdate:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .remoteSteeringWheelHeater:
                TeslaAPI.logger.debug("Command \(command.description) not implemented, privacy: .public)")
                response.result = false
                response.reason = "Command \(command.description) not implemented"
            case .remoteSeatHeater:
                guard let seat = (parameter as? RemoteSeatHeaterRequest)?.heater else {
                    response.result = false
                    response.reason = "error"
                    return response
                }
                switch seat {
                case .frontLeft:
                    DemoTesla.shared.vehicle?.climateState.seatHeaterLeft = (parameter as? RemoteSeatHeaterRequest)?.level ?? 1
                case .frontRight:
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRight = (parameter as? RemoteSeatHeaterRequest)?.level ?? 1
                case .rearLeft:
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearLeft = (parameter as? RemoteSeatHeaterRequest)?.level ?? 1
                case .rearCenter:
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearCenter = (parameter as? RemoteSeatHeaterRequest)?.level ?? 1
                case .rearRight:
                    DemoTesla.shared.vehicle?.climateState.seatHeaterRearRight = (parameter as? RemoteSeatHeaterRequest)?.level ?? 1
                default:
                    response.result = false
                    response.reason = "Command \(command.description) not implemented"
                }
            case .sentryMode:
                DemoTesla.shared.vehicle?.vehicleState.sentryMode = (parameter as! SentryMode).isOn
            case .homelink:
                if ((DemoTesla.shared.vehicle?.vehicleState.homelinkNearby) != nil)  && ((DemoTesla.shared.vehicle?.driveState.nativeLatitude == (parameter as! TriggerHomelink).lat) && (
                    DemoTesla.shared.vehicle?.driveState.nativeLongitude == (parameter as! TriggerHomelink).lon)) {
                    TeslaAPI.logger.debug("Command: \(command.description), privacy: .public)")
                    response.reason = "succesful \(command.description)"
                } else {
                    response.result = false
                    response.reason = "no homelink nearby or lat/lon not nearby"
                    TeslaAPI.logger.debug("no homelink nearby or lat/lon not nearby, privacy: .public)")
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
                    TeslaAPI.logger.debug("lat/lon not nearby, privacy: .public)")
                }
            case .setClimateMode:
                let mode = (parameter as? SetClimateMode)?.climate_keeper_mode
                if mode == 0 {
                    DemoTesla.shared.vehicle?.climateState.isClimateOn = false
                    DemoTesla.shared.vehicle?.vehicleState.centerDisplayState = 0
                } else {
                    DemoTesla.shared.vehicle?.climateState.isClimateOn = true
                    DemoTesla.shared.vehicle?.vehicleState.centerDisplayState = ClimateMode.camp.toNumber == mode ? 2 : (ClimateMode.dog.toNumber == mode ? 8 : 0)
                }
            case .share:
                response.result = false
                response.reason = "not implemented"
                TeslaAPI.logger.debug("not implemented, privacy: .public)")
            case .remoteAutoSeatClimateRequest:
                guard let param = (parameter as? RemoteAutoSeatClimateRequest) else {
                    response.result = false
                    response.reason = "error"
                    return response
                }
                if param.auto_seat_position == .frontRight {
                    DemoTesla.shared.vehicle?.climateState.auto_seat_climate_left = param.auto_climate_on ? 1 : 0
                    if !param.auto_climate_on {
                        DemoTesla.shared.vehicle?.climateState.seatHeaterLeft = 0
                    }
                } else {
                    DemoTesla.shared.vehicle?.climateState.auto_seat_climate_right = param.auto_climate_on ? 1 : 0
                    if !param.auto_climate_on {
                        DemoTesla.shared.vehicle?.climateState.seatHeaterRight = 0
                    }
                }
            }
            if #available(iOS 16.0, *) {
                #if !os(macOS)
                try await Task.sleep(until: .now + .seconds(1.5), clock: .continuous)
                #endif
                return response
            } else {
                return response
            }
        } else {
            _ = try await checkAuthentication()
            let response: CommandResponse = try await self.request(Endpoint.command(vehicleID: vehicle.id, command: command), body: nullBody, parameter: parameter?.toJSON())
            return response
        }
	}

	/**
	Sends a command tripplan
	
	- parameter for "car_trim", "car_type", "destination", "origin","origin_soe", "vin"
	- returns: Tripplan
	*/
    public func tripplan(_ vehicle: Vehicle, destination: Location, origin: Location = Location(), origin_soe: Double = -1) async throws -> Tripplan {
        var o_soe: Double = vehicle.chargeState.batteryLevel / 100
        if origin_soe != -1 {
            o_soe = origin_soe
        }
        var o_location: Location = Location(long: vehicle.driveState.longitude, lat: vehicle.driveState.latitude)
        if !(origin.long == 0 && origin.lat == 0) {
            o_location = origin
        }
        let parameter: TripplanRequest = TripplanRequest(car_trim: vehicle.vehicleConfig.trimBadging , car_type: vehicle.vehicleConfig.carType ?? "", destination: destination.description, origin: o_location.description, origin_soe: o_soe, vin: vehicle.vin?.vinString ?? "")
        if self.demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            if #available(iOS 16.0, *) {
                #if !os(macOS)
                try await Task.sleep(until: .now + .seconds(1.5), clock: .continuous)
                #endif
                return Tripplan()
            } else {
                return Tripplan()
            }
        } else {
            _ = try await checkAuthentication()
            let response: Tripplan = try await self.request(Endpoint.tripplan, body: nullBody, parameter: parameter.toJSON())
            return response
        }
    }
}


