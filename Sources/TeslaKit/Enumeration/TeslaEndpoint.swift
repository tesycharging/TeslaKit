//
//  TeslaEndpoint.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Joao Nunes on 16/04/16.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

public enum Endpoint {
    case revoke
    case oAuth2Authorization(auth: AuthCodeRequest)
    case oAuth2AuthorizationCN(auth: AuthCodeRequest)
    case oAuth2Token
    case oAuth2TokenCN
    case oAuth2revoke(token: String)
    case oAuth2revokeCN(token: String)
    case locationData(vehicleID: String) //return GPS
	case vehicles	// return VehicleCollection
    case vehicleSummary(vehicleID: String)  // vehicle summary without all states
	case mobileAccess(vehicleID: String) // returns a boolean true if car allows mobileAccess
	case allStates(vehicleID: String)  // complete vehicle infos from the car itself
	case chargeState(vehicleID: String)  // specific vehicle dates form the car itself
	case climateState(vehicleID: String) // specific vehicle dates form the car itself
	case driveState(vehicleID: String) // specific vehicle dates form the car itself
    case nearbyChargingSites(vehicleID: String) // specific vehicle dates form the car itself
	case guiSettings(vehicleID: String) // specific vehicle dates form the car itself
	case vehicleState(vehicleID: String) // specific vehicle dates form the car itself
	case vehicleConfig(vehicleID: String) // specific vehicle dates form the car itself
	case wakeUp(vehicleID: String)		// returns true if wakeup command was successful (eventhought the car is not fully online yet)
	case command(vehicleID: String, command: Command)
    case products

    case user
    case tripplan
	
    /*case getEnergySiteStatus(siteID: String)
    case getEnergySiteLiveStatus(siteID: String)
    case getEnergySiteInfo(siteID: String)
    case getEnergySiteHistory(siteID: String, period: EnergySiteHistory.Period)
    case getBatteryStatus(batteryID: String)
    case getBatteryData(batteryID: String)
    case getBatteryPowerHistory(batteryID: String)*/
}

extension Endpoint {
	
    var path: String {
        switch self {
            // Auth
            case .revoke:
                return "/oauth/revoke"
            case .oAuth2Authorization, .oAuth2AuthorizationCN:
                return "/oauth2/v3/authorize"
            case .oAuth2Token, .oAuth2TokenCN:
                return "/oauth2/v3/token"
            case .oAuth2revoke, .oAuth2revokeCN:
                return "/oauth2/v3/revoke"
            // location data
            case .locationData(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/vehicle_data"
            // Vehicle Data and Commands
            case .vehicles:
                return "/api/1/vehicles"
            case .vehicleSummary(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)"
            case .mobileAccess(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/mobile_enabled"
            case .allStates(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/vehicle_data"
            case .chargeState(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/charge_state"
            case .climateState(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/climate_state"
            case .driveState(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/drive_state"
            case .guiSettings(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/gui_settings"
            case .nearbyChargingSites(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/nearby_charging_sites"
            case .vehicleState(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/vehicle_state"
            case .vehicleConfig(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/data_request/vehicle_config"
            case .wakeUp(let vehicleID):
                return "/api/1/vehicles/\(vehicleID)/wake_up"
            case let .command(vehicleID, command):
                return "/api/1/vehicles/\(vehicleID)/\(command.path)"
            case .products:
                return "/api/1/products"

	    case .user:
		return "/api/1/users/me"
	    case .tripplan:
		return "/trip-planner/api/v1/tripplan"
            
           /* // Energy Data
            case .getEnergySiteStatus(let siteID):
                return "/api/1/energy_sites/\(siteID)/site_status"
            case .getEnergySiteLiveStatus(let siteID):
                return "/api/1/energy_sites/\(siteID)/live_status"
            case .getEnergySiteInfo(let siteID):
                return "/api/1/energy_sites/\(siteID)/site_info"
            case .getEnergySiteHistory(let siteID, _):
                return "/api/1/energy_sites/\(siteID)/history"
            case .getBatteryStatus(let batteryID):
                return "/api/1/powerwalls/\(batteryID)/status"
            case .getBatteryData(let batteryID):
                return "/api/1/powerwalls/\(batteryID)/"
            case .getBatteryPowerHistory(let batteryID):
                return "/api/1/powerwalls/\(batteryID)/powerhistory"*/
        }
	}
	
	var method: String {
		switch self {
            case .revoke, .oAuth2Token, .oAuth2TokenCN, .wakeUp, .command, .tripplan:
                return "POST"
        case .locationData, .vehicles, .vehicleSummary, .mobileAccess, .allStates, .chargeState, .climateState, .driveState, .guiSettings, .vehicleState, .vehicleConfig, .nearbyChargingSites, .oAuth2Authorization, .oAuth2revoke, .oAuth2AuthorizationCN, .oAuth2revokeCN, .products, .user/*, .getEnergySiteStatus, .getEnergySiteLiveStatus, .getEnergySiteInfo, .getEnergySiteHistory, .getBatteryStatus, .getBatteryData, .getBatteryPowerHistory*/:
                return "GET"
		}
	}

    var queryParameters: [URLQueryItem] {
        switch self {
            case let .oAuth2Authorization(auth):
                return auth.parameters()
            case let .oAuth2revoke(token):
                return [URLQueryItem(name: "token", value: token)]
            /*case let .getEnergySiteHistory(_, period):
                return [URLQueryItem(name: "period", value: period.rawValue), URLQueryItem(name: "kind", value: "energy")]*/
        case .locationData(_):
                return [URLQueryItem(name: "endpoints", value: "location_data")]
            default:
                return []
        }
    }

    func baseURL() -> String {
        switch self {
            case .oAuth2Authorization, .oAuth2Token, .oAuth2revoke:
                return "https://auth.tesla.com"
            case .oAuth2AuthorizationCN, .oAuth2TokenCN, .oAuth2revokeCN:
                return "https://auth.tesla.cn"
            default:
                return "https://owner-api.teslamotors.com"
        }
    }
}

