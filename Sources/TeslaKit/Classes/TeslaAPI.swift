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
    public static func == (lhs: TeslaError, rhs: TeslaError) -> Bool {
        true
    }

    case networkError(msg: String)
    case authenticationRequired(code: Int, msg: String)
    case authenticationFailed(code: Int, msg: String)
    case failedToParseData(code: Int, msg: String)
    case apiError(code: Int, msg: String)
    
    public var description: String {
        switch self {
        case .networkError(let msg): return "Network Error: \(msg)"
        case .authenticationRequired(let code, let msg): return "Authentication Required: Error \(code) \(msg)"
        case .authenticationFailed(let code, let msg): return "Authentication Failed: Error \(code) \(msg)"
        case .failedToParseData(let code, let msg): return "Failed To Parse Data: Error \(code) \(msg)"
        case .apiError(let code, let msg): return "Error \(code): \(msg)"
        }
    }
}

public enum AuthorizationScope: String {
    case openid = "openid"
    case offline_access = "offline_access"
    case user_data = "user_data"
    case vehicle_device_data = "vehicle_device_data"
    case vehicle_cmds = "vehicle_cmds"
    case vehicle_charging_cmds = "vehicle_charging_cmds"
    case energy_device_data = "energy_device_data"
    case energy_cmds = "energy_cmds"
}

open class TeslaAPI: NSObject, URLSessionDelegate {
    open var debuggingEnabled = false
	open var demoMode = false
    open var addDemoVehicle = true
    public var officialAPI = true
    public var authTokenReqest: AuthTokenRequestWeb
    public var authCodeRequest: AuthCodeRequest
    public let domain: String

    open fileprivate(set) var token: AuthToken?
    open fileprivate(set) var fleet_api_base_url: String = ""
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: TeslaAPI.self))
    
    /**
     initializing the unofficial API
     */
    public override init () {
        self.officialAPI = false
        self.authTokenReqest = AuthTokenRequestWeb(clientID: "", client_secret: "", scope: "")
        self.authCodeRequest = AuthCodeRequest(clientID: "", redirect_uri: "", scope: "")
        self.domain = ""
    }
    
    /**
     initalizing the official API
     - clientID: Partner application client id.
     - client_secret:  Partner application client secret.
     - domain: Partner domain used to validate registration flow.
     - redirect_uri:  Partner application callback url, spec: rfc6749.
     - authorizationScope: list of scopes.
     */
    public init(clientID: String, client_secret: String, domain: String, redirect_uri: String, authorizationScope: [AuthorizationScope] = [.openid, .offline_access, .user_data, .vehicle_device_data, .vehicle_cmds, .vehicle_charging_cmds]) {
        self.officialAPI = true
        self.authTokenReqest = AuthTokenRequestWeb(clientID: clientID, client_secret: client_secret, scope: authorizationScope.map({$0.rawValue}).joined(separator: " "))
        self.authCodeRequest = AuthCodeRequest(clientID: clientID, redirect_uri: redirect_uri, scope: authorizationScope.map({$0.rawValue}).joined(separator: " "))
        self.domain = domain
    }
    
}

@available(macOS 13.1, *)
extension TeslaAPI {
    /**
     #1: Generating a partner authentication token by POST https://auth.tesla.com/oauth2/v3/token
     #2: register by POST https://fleet-api.prd.na.vn.cloud.tesla.com/api/1/partner_accounts
     */
    public func registerThirdPartyAPI() async throws {
        let partnerToken: AuthToken = try await self.request(Endpoint.oAuth2PartnerAuthorization, parameter: self.authTokenReqest.toJSON(), token: nil)
        let _: CommandResponse = try await self.request(Endpoint.register, parameter: RegisterAccount(domain: domain).toJSON(), token: partnerToken)
    }
}

@available(macOS 13.1, *)
extension TeslaAPI {

	public var isAuthenticated: Bool {
        return demoMode ? true : (token != nil && (token?.isValid ?? false))
    }
 
	/**
      #3 Generating a third-party token on behalf of a customer initiate the authorization code flow, direct the customer to an /authorize request by GET https://auth.tesla.com/oauth2/v3/authorize
     
        Performs the authentition with the Tesla API for web logins

      For MFA users, this is the only way to authenticate.
      If the token expires, a token refresh will be done

      - returns: A ViewController that your app needs to present. This ViewContoller will ask the user for his/her Tesla credentials, MFA code if set and then desmiss on successful authentication
	  An async function that returns when the token as been retrieved
     */
    //#if canImport(WebKit) && canImport(UIKit)
    public func authenticateWeb() -> (TeslaWebLoginViewController?, () async throws -> AuthToken) {
        let codeRequest = !officialAPI ? AuthCodeRequest() : self.authCodeRequest
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        
        guard let safeUrlComponents = urlComponents else {
            func error() async throws -> AuthToken {
                throw TeslaError.authenticationFailed(code: 0, msg: "")
            }
            return (nil, error)
        }
        let teslaWebLoginViewController = TeslaWebLoginViewController(url: safeUrlComponents.url!, redirect_uri: codeRequest.redirectURI)
        
        func result() async throws -> AuthToken {
            let url = try await teslaWebLoginViewController.result()
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            if let queryItems = urlComponents?.queryItems, let code = queryItems.first(where: { $0.name == "code" })?.value, let state = queryItems.first(where: { $0.name == "state" }) {
                if "\(state)" == "state=\(codeRequest.state)" {
                    return try await self.getAuthenticationTokenForWeb(codeRequest.codeVerifier ?? "", code: code)
                } else {
                    throw TeslaError.authenticationFailed(code: 0, msg: "state is different in callback")
                }
            }
            throw TeslaError.authenticationFailed(code: 0, msg: "no code parameter in callback")
        }
        return (teslaWebLoginViewController, result)
    }
    //#endif
    
    /**
     #4: Execute a code exchange call to generate a token by POST https://auth.tesla.com/oauth2/v3/token
     */
    private func getAuthenticationTokenForWeb(_ codeVerifier: String = "", code: String) async throws -> AuthToken {
        let parameter = !officialAPI ? AuthTokenRequestWeb(codeVerifier, code: code) : AuthTokenRequestWeb(clientID: authTokenReqest.clientID, client_secret: authTokenReqest.client_secret, redirect_uri: authCodeRequest.redirectURI, code: code)
        let token: AuthToken = try await request(.oAuth2Token, parameter: parameter.toJSON())
        self.token = token
        fleet_api_base_url = try await getRegion()
        return token
    }
    
    /**
     #5: Use the refresh_token to generate new tokens and obtain refresh tokens by Post https://auth.tesla.com/oauth2/v3/token
     
     Performs the token refresh with the Tesla API for Web logins

     - returns: The AuthToken.
	 An async function that returns when the token as been requested
     */
    public func refreshWebToken() async throws -> AuthToken {
        guard let token = self.token else { throw TeslaError.authenticationRequired(code: 0, msg: "no valid token") }
        let parameter = !officialAPI ? AuthTokenRequestWeb(grantType: .refreshToken, refreshToken: token.refreshToken) : AuthTokenRequestWeb(grantType: .refreshToken, clientID: authTokenReqest.clientID, refreshToken: token.refreshToken)
        let authToken: AuthToken = try await request(.oAuth2Token, parameter: parameter.toJSON())
        self.token = authToken
        fleet_api_base_url = try await getRegion()
        return authToken
    }
    
    /**
     #6: region by GET https://fleet-api.prd.na.vn.cloud.tesla.com/api/1/users/region
     -returns https://fleet-api.prd.na.vn.cloud.tesla.com or https://fleet-api.prd.eu.vn.cloud.tesla.com
     */
    public func getRegion() async throws -> String {
        func getRegion<T: DataResponse>() async throws -> T? {
            let response = try await self.request(.region, token: token) as T
            return response
        }
        
        if officialAPI  {
            guard let regionAccount: RegionAccount = try await getRegion() else { return fleet_api_base_url }
            fleet_api_base_url = regionAccount.fleet_api_base_url
            return regionAccount.fleet_api_base_url
        } else {
            fleet_api_base_url = "https://owner-api.teslamotors.com"
            return "https://owner-api.teslamotors.com"
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

        let response: BoolResponse = try await request(.oAuth2revoke(token: accessToken))
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
            guard let token = self.token else { throw TeslaError.authenticationRequired(code: 0, msg: "no valid token") }
        
            if self.isAuthenticated {
                return token
            } else {
                if token.refreshToken != nil {
                    self.token = try await refreshWebToken()
                    return self.token!
                } else {
                    throw TeslaError.authenticationRequired(code: 0, msg: "no valid token")
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
	  return try await getVehicleData(.user(fleet_api_base_url: fleet_api_base_url))
  }
    
    /**
        Fetches the endpoint, e.g. location_datas
     */
    public func getEndpoint<T: DataResponse>(_ vehicleID: String, endpoint: VehicleEndpoint) async throws -> T? {
        _ = try await checkAuthentication()
        if self.demoMode {
            return DemoTesla.shared.getEndpoint(endpoint: endpoint)
        } else {
            let response = try await self.request(Endpoint.vehicleEndpoint(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicleID, endpoint: endpoint), token: token) as T
            return response
        }
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
			let response: VehicleCollection = try await request(.vehicles(fleet_api_base_url: fleet_api_base_url), token: token)
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
            case .allStates(_,_), .vehicleSummary(_,_):
                return ((DemoTesla.shared.vehicle)! as! T)
            case .user:
                return (DemoTesla.shared.user as! T)
            case .region:
                return (RegionAccount() as! T)
            default:
                throw TeslaError.failedToParseData(code: 0, msg: "\(method) is not implemented")
            }
        } else {
            let response = try await self.request(method, token: token) as T
            return response
        }
    }
    
    
    /**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicleInfo(_ vehicleID: String) async throws -> Vehicle? {
        return try await getVehicleData(.vehicleSummary(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicleID))
    }
    
   /**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    public func getVehicleInfo(_ vehicle: Vehicle) async throws -> Vehicle? {
        return try await getVehicleData(.vehicleSummary(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id))
    }
	
	/**
    Fetchs the summary of a vehicle
    
    - returns: A Vehicle.
    */
    @available(*, deprecated, message: "getAllData")
    public func getVehicle(_ vehicleID: String) async throws -> Vehicle? {
        return try await getVehicleData(.allStates(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicleID))
    }
	
	/**
    Fetches the summary of a vehicle
    
    - returns: A Vehicle.
    */
    @available(*, deprecated, message: "getAllData")
    public func getVehicle(_ vehicle: Vehicle) async throws -> Vehicle? {
        return try await getVehicleData(.allStates(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), demoMode: (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"))
    }
	
	/**
     Fetches the vehicle data
     
     - returns: A completion handler with all the data
     */
    public func getAllData(_ vehicle: Vehicle) async throws -> Vehicle? {
        return try await getVehicleData(.allStates(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), demoMode: (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"))
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
            let response: MobileAccess = try await self.request(Endpoint.mobileAccess(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), token: token)
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
            let response: Chargingsites = try await self.request(Endpoint.nearbyChargingSites(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), token: token)
            return response
        }
    }
	
	/**
	Wakes up the vehicle
	
	- returns: always true. It takes a while (~30 seconds) after return till the vehicle is online
	*/
    @available(*, deprecated, message: "use wakeUpVehicle")
    public func wakeUp(_ vehicle: Vehicle) async throws -> Bool {
        if demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            return true
        } else {
            _ = try await checkAuthentication()
            _ = try await self.request(Endpoint.wakeUp(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), token: token) as Vehicle
            return true
        }
	}
    
    /**
    Wakes up the vehicle
    
    - returns: vehicle
    */
    public func wakeUpVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        if demoMode || (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
            return vehicle
        } else {
            _ = try await checkAuthentication()
            return try await self.request(Endpoint.wakeUp(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), token: token) as Vehicle
        }
    }
    
    public func chargingHistory(_ vehicle: Vehicle) async throws -> [ChargingSession] {
        if demoMode {
            return [ChargingSession]()
        } else {
            _ = try await checkAuthentication()
            let chargingHistory: ChargingHistory = try await self.request(Endpoint.charging_history(fleet_api_base_url: fleet_api_base_url, query: [URLQueryItem(name: "vin", value: vehicle.vin?.vinString),URLQueryItem(name: "startTime", value: "2020-10-10T10:00:00+01:00")]), token: token)
            return chargingHistory.data
        }
    }
    
    public func optionCodes(_ vehicle: Vehicle) async throws -> [OptionCode] {
        if demoMode {
            return [OptionCode]()
        } else {
            _ = try await checkAuthentication()
            let optionCodes: OptionCodes = try await self.request(Endpoint.options(fleet_api_base_url: fleet_api_base_url, vin: vehicle.vin?.vinString ?? ""), token: token)
            return optionCodes.codes
        }
    }
    
    public func getRecentAlerts(_ vehicle: Vehicle) async throws -> [Recent_Alert] {
        if demoMode {
            return [Recent_Alert]()
        } else {
            _ = try await checkAuthentication()
            let recentAlerts: Alerts = try await self.request(Endpoint.recent_alerts(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id), token: token)
            return recentAlerts.recent_alerts
        }
    }
    
}

@available(macOS 13.1, *)
extension TeslaAPI {
    func prepareRequest(_ endpoint: Endpoint, parameter: Any? = nil, token: AuthToken?) -> URLRequest {
        var urlComponents = URLComponents(url: URL(string: endpoint.baseURL())!, resolvingAgainstBaseURL: true)
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = endpoint.method

        if let token = token?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let parameter = parameter {
            if debuggingEnabled {
                TeslaAPI.logger.debug("method: \(endpoint.method), privacy: .public)")
                TeslaAPI.logger.debug("baseURL: \(endpoint.baseURL()), privacy: .public)")
                TeslaAPI.logger.debug("path: \(endpoint.path), privacy: .public)")
                TeslaAPI.logger.debug("queryParameters: \(endpoint.queryParameters), privacy: .public)")
            }
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.setValue("no-cache", forHTTPHeaderField: "cache-control")
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameter)
        }
        
        return request
    }
            
	
    public func request<T: Mappable>(_ endpoint: Endpoint, parameter: Any? = nil, token: AuthToken? = nil) async throws -> T {
        // Create the request
        if URL(string: endpoint.baseURL()) == nil {
            throw TeslaError.authenticationFailed(code: 0, msg: "should set region by refreshing the token")
        }
        let request = prepareRequest(endpoint, parameter: parameter, token: token)
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
                        continuation.resume(with: .failure(error ?? TeslaError.failedToParseData(code: 0, msg: "internal")))
                    }
                }
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { throw TeslaError.failedToParseData(code: 0, msg: "no HTTPResponse") }
        if debugEnabled {
            TeslaAPI.logger.debug("RESPONSE: \(httpResponse.url!), privacy: .public)")
            TeslaAPI.logger.debug("STATUS CODE: \(httpResponse.statusCode), privacy: .public)")
            TeslaAPI.logger.debug("HEADERS: \(httpResponse.allHeaderFields), privacy: .public)")
            TeslaAPI.logger.debug("DATA: \(String(data: data, encoding: .utf8) ?? ""), privacy: .public)")
        }
        
        switch httpResponse.statusCode {
        case 200,201:
            //200: The request was handled successfully;201: The record was created successfully.
            // Attempt to serialize the response JSON and map to TeslaKit objects
            do {
                let json: Any = try JSONSerialization.jsonObject(with: data)
                guard let mappedVehicle = Mapper<T>().map(JSONObject: json) else {
                    throw TeslaError.failedToParseData(code: httpResponse.statusCode, msg: String(data: data, encoding: .utf8) ?? "failed to map to type")
                }
                return mappedVehicle
            } catch let error {
                TeslaAPI.logger.debug("\(error.localizedDescription), privacy: .public)")
                throw TeslaError.failedToParseData(code: httpResponse.statusCode, msg: String(data: data, encoding: .utf8) ?? "failed to map to type")
            }
        case 400, 401, 402, 403, 404, 405, 406, 408, 412, 418, 421, 422, 423, 429, 451, 499, 500, 503, 504, 540:
            //case 400: Bad Request
            //case 401: Unauthorized
            //case 402: Payment Required
            //case 403: Forbidden
            //case 404: Not Found
            //case 405: Not Allowed
            //case 406: Not Acceptable
            //case 408: Device Not Available
            //case 412: Precondition Failed
            //case 418: Client Too Old (Not supported)
            //case 421: Incorrect region
            //case 422: Invalid Resource
            //case 423: Locked
            //case 429: Rate limited
            //case 451: Resource Unavailable For Legal Reasons
            //case 499: Client Closed Request
            //case 500: Internal server error
            //case 503: Service Unavailable
            //case 504: Gateway Timeout
            //case 540: Device Unexpected response
            let json: Any = try JSONSerialization.jsonObject(with: data)
            guard let mappedError = Mapper<ErrorMessage>().map(JSONObject: json) else {
                throw TeslaError.authenticationFailed(code: httpResponse.statusCode, msg: String(data: data, encoding: .utf8) ?? "")
            }
            let error = mappedError.toJSON()["error"]
            TeslaAPI.logger.debug("\(mappedError.toJSON()), privacy: .public)")
            if mappedError.error == "invalid bearer token" {
                throw TeslaError.authenticationFailed(code: httpResponse.statusCode, msg: mappedError.error)
            } else {
                throw TeslaError.apiError(code: httpResponse.statusCode, msg: error as! String)
            }
        default:
            let json: Any = try JSONSerialization.jsonObject(with: data)
            guard let mappedError = Mapper<ErrorMessage>().map(JSONObject: json) else {
                if let wwwauthenticate = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
                   wwwauthenticate.contains("invalid_token") {
                    throw TeslaError.authenticationRequired(code: httpResponse.statusCode, msg: "invalid token")
                } else {
                    throw TeslaError.networkError(msg: String(data: data, encoding: .utf8) ?? "")
                }
            }
            TeslaAPI.logger.debug("\(mappedError.toJSON()), privacy: .public)")
            throw TeslaError.networkError(msg: mappedError.toJSONString() ?? "network error")
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
            case .take_drivenote:
                response.result = false
                response.reason = "not implemented"
                TeslaAPI.logger.debug("not implemented, privacy: .public)")
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
            let response: CommandResponse = try await self.request(Endpoint.command(fleet_api_base_url: fleet_api_base_url, vehicleID: vehicle.id, command: command), parameter: parameter?.toJSON(), token: token)
            return response
        }
	}

	/**
	Sends a command tripplan
	
	- parameter for "car_trim", "car_type", "destination", "origin","origin_soe", "vin"
	- returns: Tripplan
	*/
    public func tripplan(parameter: BaseMappable) async throws -> Tripplan {
        if self.demoMode {
            if #available(iOS 16.0, *) {
                #if !os(macOS)
                try await Task.sleep(until: .now + .seconds(1.5), clock: .continuous)
                #endif
                throw NSError(domain: "tripplan not available in demo mode", code: 0)
            } else {
                throw NSError(domain: "tripplan not available in demo mode", code: 0)
            }
        } else {
            _ = try await checkAuthentication()
            let response: Tripplan = try await self.request(Endpoint.tripplan(fleet_api_base_url: fleet_api_base_url), parameter: parameter.toJSON(), token: token)
            return response
        }
    }
}

public class CountRequests: ObservableObject {
    static public let shared = CountRequests()
    
    @Published public var requestAPI: [APIReqType: Int] = [APIReqType: Int]()
    
    func incrementRequest(endpoint: Endpoint) {
        requestAPI[endpoint.apiRequestType] = (requestAPI[endpoint.apiRequestType] ?? 0) + 1
    }
    
}
