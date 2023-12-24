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
    case revoke(fleet_api_base_url: String)
    case oAuth2PartnerAuthorization
    case register
    case oAuth2Authorization(auth: AuthCodeRequest)
    case oAuth2AuthorizationCN(auth: AuthCodeRequest)
    case oAuth2Token
    case oAuth2TokenCN
    case region
    case oAuth2revoke(token: String)
    case oAuth2revokeCN(token: String)
    case vehicles(fleet_api_base_url: String)	// return VehicleCollection
    case vehicleSummary(fleet_api_base_url: String, vehicleID: String)  // vehicle summary without all states
	case mobileAccess(fleet_api_base_url: String, vehicleID: String) // returns a boolean true if car allows mobileAccess
    case allStates(fleet_api_base_url: String, vehicleID: String)  // complete vehicle infos from the car itself
    case vehicleEndpoint(fleet_api_base_url: String, vehicleID: String, endpoint: VehicleEndpoint)
	case nearbyChargingSites(fleet_api_base_url: String, vehicleID: String) // specific vehicle dates form the car itself
	case wakeUp(fleet_api_base_url: String, vehicleID: String)		// returns true if wakeup command was successful (eventhought the car is not fully online yet)
	case command(fleet_api_base_url: String, vehicleID: String, command: Command)
    case products(fleet_api_base_url: String)

    case user(fleet_api_base_url: String)
    case tripplan(fleet_api_base_url: String)
	
    /*case getEnergySiteStatus(siteID: String)
    case getEnergySiteLiveStatus(siteID: String)
    case getEnergySiteInfo(siteID: String)
    case getEnergySiteHistory(siteID: String, period: EnergySiteHistory.Period)
    case getBatteryStatus(batteryID: String)
    case getBatteryData(batteryID: String)
    case getBatteryPowerHistory(batteryID: String)*/
}

public enum VehicleEndpoint: String {
    case chargeState = "charge_state"
    case climateState = "climate_state"
    case closuresState = "closures_state"
    case driveState = "drive_state"
    case guiSettings = "gui_settings"
    case locationData = "location_data"
    case vehicleConfig = "vehicle_config"
    case vehicleState = "vehicle_state"
    case vehicleDataCombo = "vehicle_data_combo"
}


extension Endpoint {
	
    var path: String {
        switch self {
        // Auth
        case .revoke:
            return "/oauth/revoke"
        case .oAuth2Authorization, .oAuth2AuthorizationCN:
            return "/oauth2/v3/authorize"
        case .oAuth2PartnerAuthorization, .oAuth2Token, .oAuth2TokenCN:
            return "/oauth2/v3/token"
        case .region:
            return "/api/1/users/region"
        case .oAuth2revoke, .oAuth2revokeCN:
            return "/oauth2/v3/revoke"
        case .register:
            return "/api/1/partner_accounts"
        // Vehicle Data and Commands
        case .vehicles:
            return "/api/1/vehicles"
        case .vehicleSummary(_, let vehicleID):
            return "/api/1/vehicles/\(vehicleID)"
        case .mobileAccess( _, let vehicleID):
            return "/api/1/vehicles/\(vehicleID)/mobile_enabled"
        case .vehicleEndpoint(_, let vehicleID, _):
            return "/api/1/vehicles/\(vehicleID)/vehicle_data"
        case .allStates( _, let vehicleID):
            return "/api/1/vehicles/\(vehicleID)/vehicle_data"
        case .nearbyChargingSites( _, let vehicleID):
            return "/api/1/vehicles/\(vehicleID)/nearby_charging_sites"
        case .wakeUp( _, let vehicleID):
            return "/api/1/vehicles/\(vehicleID)/wake_up"
        case .command(_, let vehicleID, let command):
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
        case .revoke, .oAuth2PartnerAuthorization, .register, .oAuth2Token, .oAuth2TokenCN, .wakeUp, .command, .tripplan:
                return "POST"
        case .vehicles, .vehicleSummary, .mobileAccess, .allStates, .vehicleEndpoint, .nearbyChargingSites, .oAuth2Authorization, .oAuth2revoke, .oAuth2AuthorizationCN, .region, .oAuth2revokeCN, .products, .user/*, .getEnergySiteStatus, .getEnergySiteLiveStatus, .getEnergySiteInfo, .getEnergySiteHistory, .getBatteryStatus, .getBatteryData, .getBatteryPowerHistory*/:
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
        case let .vehicleEndpoint(_,_,endpoint):
            return [URLQueryItem(name: "endpoints", value: endpoint.rawValue)]
        default:
            return []
        }
    }

    func baseURL() -> String {
        switch self {
        case .oAuth2Authorization, .oAuth2PartnerAuthorization, .oAuth2Token, .oAuth2revoke:
            return "https://auth.tesla.com"
        case .oAuth2AuthorizationCN, .oAuth2TokenCN, .oAuth2revokeCN:
            return "https://auth.tesla.cn"
        case .region:
            return "https://fleet-api.prd.na.vn.cloud.tesla.com"
        case .register:
            return "https://fleet-api.prd.na.vn.cloud.tesla.com"
        case let .user(fleet_api_base_url):
            return fleet_api_base_url
        case let .vehicles(fleet_api_base_url), let .allStates(fleet_api_base_url, _):
            return fleet_api_base_url
        case let .vehicleEndpoint(fleet_api_base_url,_,_):
            return fleet_api_base_url
        case let .mobileAccess(fleet_api_base_url, _):
            return fleet_api_base_url
        case let .wakeUp(fleet_api_base_url, _):
            return fleet_api_base_url
        case let .nearbyChargingSites(fleet_api_base_url, _):
            return fleet_api_base_url
        case let .tripplan(fleet_api_base_url):
            return fleet_api_base_url
        case let .products(fleet_api_base_url):
            return fleet_api_base_url
        case let .command(fleet_api_base_url, _, _):
            return fleet_api_base_url
        case let .revoke(fleet_api_base_url):
            return fleet_api_base_url
        case let .vehicleSummary(fleet_api_base_url, _):
            return fleet_api_base_url
        }
    }
}

