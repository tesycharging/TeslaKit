//
//  DemoTesla.swift
//  TeslaKit
//
//  Created by David Lüthi on 14.03.21
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
//import TeslaKit
import ObjectMapper

public class DemoTesla {
    public static let shared = DemoTesla()
	public var vehicle: Vehicle?
	public var vehicles: VehicleCollection = VehicleCollection()
    
    public var chargingState: ChargingState = ChargingState.disconnected
    public var chargePortLatch: ChargePortLatchState = ChargePortLatchState.disengaged
    public var batteryLevel: Double = 50
    public var batteryRange: Double = 180
    public var chargeEnergyAdded: Double = 0
    public var chargeLimitSoc: Int = 80
    public var chargePortDoorOpen: Bool = false
    public var fastChargerBrand: String = "Tesla"
    public var fastChargerPresent: Bool = true
    public var fastChargerType: String = "Combo"
    public var idealBatteryRange: Double = 50
    public var timeToFullCharge: Double = 0
    public var usableBatteryLevel: Double = 50
    public var locked: Bool = true
    public var isTrunkOpen: Bool = false
    public var isFrunkOpen: Bool = false
    public var odometer: Double = Date().timeIntervalSince1970 / 20000
    public var power: Int = 100
	
	public init() {
        self.vehicle = requestDemoVehicle()
        self.vehicle?.vin = VIN(vinString: "VIN#DEMO_#TESTING")
        self.vehicle?.chargeState.chargeEnergyAdded = 0
        self.vehicle?.chargeState.batteryLevel = 50
        self.vehicle?.chargeState.batteryRange = 180
        self.vehicle?.chargeState.usableBatteryLevel = 50
        self.vehicle?.chargeState.idealBatteryRange = 200
        self.vehicle?.chargeState.chargeLimitSoc = 80
        self.vehicle?.chargeState.chargingState = .disconnected
        self.vehicle?.chargeState.chargePortLatch = .disengaged
        self.vehicle?.chargeState.chargePortDoorOpen = false
        self.vehicle?.chargeState.fastChargerBrand = "Tesla"
        self.vehicle?.chargeState.fastChargerPresent = true
        self.vehicle?.chargeState.fastChargerType = "Combo"
        self.vehicle?.chargeState.chargerPower = 100
        self.vehicle?.vehicleState.odometer = Date().timeIntervalSince1970 / 20000
        self.vehicle?.vehicleState.tpms_pressure_fl = 3.2
        self.vehicle?.vehicleState.tpms_pressure_fr = 3.2
        self.vehicle?.vehicleState.tpms_pressure_rl = 2.9
        self.vehicle?.vehicleState.tpms_pressure_rr = 2.9
        self.vehicle?.vehicleState.homelinkdevicecount = 1
        var vehicles = [Vehicle]()
        vehicles.append(self.vehicle ?? Vehicle())
        self.vehicles = VehicleCollection(vehicles: vehicles)
	}
    
    public func engageCable() {
        self.vehicle!.chargeState.chargePortDoorOpen = true
        if self.vehicle?.chargeState.chargingState == .disconnected {
            self.vehicle?.chargeState.chargingState = .stopped
            self.vehicle?.chargeState.chargePortLatch = .engaged
        } else if self.vehicle?.chargeState.chargingState == .stopped || self.vehicle?.chargeState.chargingState == .complete {
            self.vehicle?.chargeState.chargingState = .disconnected
            self.vehicle?.chargeState.chargePortLatch = .disengaged
        }
        
    }
    
    
    public func startCharging() {
        if (self.vehicle?.chargeState.chargeLimitSoc ?? 0) <= (self.vehicle?.chargeState.usableBatteryLevel ?? 0){
            self.vehicle?.chargeState.chargingState = ChargingState.stopped
        } else {
            self.vehicle?.chargeState.chargingState = ChargingState.charging
            self.charging()
        }
    }
    
    private func charging() {
        let bat = ((self.vehicle?.chargeState.batteryLevel) ?? 0) + 2.0
        self.vehicle?.chargeState.batteryLevel = bat
        let t1 = 75 / 100 * (Double((self.vehicle?.chargeState.chargeLimitSoc) ?? 0))
        self.vehicle!.chargeState.timeToFullCharge = (t1 - self.vehicle!.chargeState.chargeEnergyAdded) / 45 * exp(0.153007256714785)
        self.vehicle!.chargeState.chargeEnergyAdded = self.vehicle!.chargeState.chargeEnergyAdded + 1.5
        if (Double((self.vehicle?.chargeState.chargeLimitSoc)!) <= (self.vehicle?.chargeState.batteryLevel)!) {
            self.vehicle!.chargeState.chargingState = ChargingState.complete
        } else if self.vehicle!.chargeState.chargingState != ChargingState.stopped {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+3.0) {
                self.charging()
            }
        }
    }
    
    public func stopCharging() {
        if self.vehicle!.chargeState.chargingState == .stopped || self.vehicle!.chargeState.chargingState == .complete {
            //self.vehicle!.chargeState.chargingState = .complete
            self.vehicle?.chargeState.chargingState = .disconnected
            self.vehicle?.chargeState.chargePortLatch = .disengaged
        } else {
            self.vehicle!.chargeState.chargingState = ChargingState.stopped
        }
    }
    
    private func requestDemoVehicle<T: TKMappable>() -> T? {
        var mappedData: T? = nil
        let rt = 0
        let ft = 0
        
        let dataString = "{\"response\":{\"id\":1,\"user_id\":1,\"vehicle_id\":1,\"vin\":\"VIN#DEMO\",\"display_name\":\"My Tesla Model 3\",\"option_codes\":\"AD15,MDL3,PBSB,RENA,BT37,ID3W,RF3G,S3PB,DRLH,DV2W,W39B,APF0,COUS,BC3B,CH07,PC30,FC3P,FG31,GLFR,HL31,HM31,IL31,LTPB,MR31,FM3B,RS3H,SA3P,STCP,SC04,SU3C,T3CA,TW00,TM00,UT3P,WR00,AU3P,APH3,AF00,ZCST,MI00,CDM0\",\"color\":null,\"access_type\":\"OWNER\",\"tokens\":[\"a\",\"b\"],\"state\":\"online\",\"in_service\":false,\"id_s\":\"1\",\"calendar_enabled\":true,\"api_version\":15,\"backseat_token\":null,\"backseat_token_updated_at\":null,\"command_signing\":\"off\",\"charge_state\":{\"battery_heater_on\":false,\"battery_level\":\(batteryLevel),\"battery_range\":\(batteryRange),\"charge_current_request\":16,\"charge_current_request_max\":16,\"charge_enable_request\":true,\"charge_energy_added\":\(chargeEnergyAdded),\"charge_limit_soc\":\(chargeLimitSoc),\"charge_limit_soc_max\":100,\"charge_limit_soc_min\":50,\"charge_limit_soc_std\":90,\"charge_miles_added_ideal\":24.0,\"charge_miles_added_rated\":24.0,\"charge_port_cold_weather_mode\":false,\"charge_port_door_open\":\(chargePortDoorOpen),\"charge_port_latch\":\"\(chargePortLatch)\",\"charge_rate\":0.0,\"charge_to_max_range\":false,\"charger_actual_current\":0,\"charger_phases\":null,\"charger_pilot_current\":16,\"charger_power\":\(power),\"charger_voltage\":2,\"charging_state\":\"\(chargingState.rawValue)\",\"conn_charge_cable\":\"<invalid>\",\"est_battery_range\":101.87,\"fast_charger_brand\":\"\(fastChargerBrand)\",\"fast_charger_present\":\(fastChargerPresent),\"fast_charger_type\":\"\(fastChargerType)\",\"ideal_battery_range\":\(idealBatteryRange),\"managed_charging_active\":false,\"managed_charging_start_time\":null,\"managed_charging_user_canceled\":false,\"max_range_charge_counter\":0,\"minutes_to_full_charge\":0,\"not_enough_power_to_heat\":null,\"scheduled_charging_pending\":false,\"scheduled_charging_start_time\":null,\"time_to_full_charge\":\(timeToFullCharge),\"timestamp\":\(Date().timeIntervalSince1970),\"trip_charging\":false,\"usable_battery_level\":\(usableBatteryLevel),\"user_charge_enable_request\":null},\"climate_state\":{\"battery_heater\":false,\"battery_heater_no_power\":null,\"climate_keeper_mode\":\"off\",\"defrost_mode\":0,\"driver_temp_setting\":20.0,\"fan_status\":0,\"inside_temp\":21.1,\"is_auto_conditioning_on\":false,\"is_climate_on\":false,\"is_front_defroster_on\":false,\"is_preconditioning\":false,\"is_rear_defroster_on\":false,\"left_temp_direction\":0,\"max_avail_temp\":28.0,\"min_avail_temp\":15.0,\"outside_temp\":32.0,\"passenger_temp_setting\":20.0,\"remote_heater_control_enabled\":false,\"right_temp_direction\":0,\"seat_heater_left\":0,\"seat_heater_rear_center\":0,\"seat_heater_rear_left\":0,\"seat_heater_rear_right\":0,\"seat_heater_right\":0,\"side_mirror_heaters\":false,\"timestamp\":\(Date().timeIntervalSince1970),\"wiper_blade_heater\":false},\"drive_state\":{\"gps_as_of\":1615722198,\"heading\":178,\"latitude\":46.49699,\"longitude\":9.84191,\"native_latitude\":46.49699,\"native_location_supported\":1,\"native_longitude\":9.84191,\"native_type\":\"wgs\",\"power\":0,\"shift_state\":null,\"speed\":null,\"timestamp\":\(Date().timeIntervalSince1970)},\"gui_settings\":{\"gui_24_hour_time\":true,\"gui_charge_rate_units\":\"km/hr\",\"gui_distance_units\":\"km/hr\",\"gui_range_display\":\"Rated\",\"gui_temperature_units\":\"C\",\"show_range_units\":false,\"timestamp\":\(Date().timeIntervalSince1970)},\"vehicle_config\":{\"can_accept_navigation_requests\":true,\"can_actuate_trunks\":true,\"car_special_type\":\"base\",\"car_type\":\"model3\",\"charge_port_type\":\"CCS\",\"default_charge_to_max\":false,\"ece_restrictions\":true,\"eu_vehicle\":true,\"exterior_color\":\"Pink\",\"exterior_trim\":\"Chrome\",\"has_air_suspension\":false,\"has_ludicrous_mode\":true,\"key_version\":2,\"motorized_charge_port\":true,\"plg\":false,\"rear_seat_heaters\":1,\"rear_seat_type\":null,\"rhd\":false,\"roof_color\":\"RoofColorGlass\",\"seat_type\":null,\"spoiler_type\":\"None\",\"sun_roof_installed\":null,\"third_row_seats\":\"None\",\"timestamp\":\(Date().timeIntervalSince1970),\"use_range_badging\":true,\"wheel_type\":\"Pinwheel18\"},\"vehicle_state\":{\"api_version\":15,\"autopark_state_v2\":\"ready\",\"autopark_style\":\"dead_man\",\"calendar_supported\":true,\"car_version\":\"DEMO\",\"center_display_state\":0,\"df\":0,\"dr\":0,\"fd_window\":0,\"fp_window\":0,\"ft\":\(ft),\"homelink_device_count\":1,\"homelink_nearby\":true,\"is_user_present\":false,\"last_autopark_error\":\"no_error\",\"locked\":\(locked),\"media_state\":{\"remote_control_enabled\":true},\"notifications_supported\":true,\"odometer\":\(odometer),\"parsed_calendar_supported\":true,\"pf\":0,\"pr\":0,\"rd_window\":0,\"remote_start\":false,\"remote_start_enabled\":true,\"remote_start_supported\":true,\"rp_window\":0,\"rt\":\(rt),\"sentry_mode\":false,\"sentry_mode_available\":true,\"smart_summon_available\":true,\"software_update\":{\"download_perc\":0,\"expected_duration_sec\":2700,\"install_perc\":1,\"status\":\"\",\"version\":\"Demo\"},\"speed_limit_mode\":{\"active\":false,\"current_limit_mph\":50.0,\"max_limit_mph\":90,\"min_limit_mph\":50,\"pin_code_set\":false},\"summon_standby_mode_enabled\":false,\"timestamp\":\(Date().timeIntervalSince1970),\"valet_mode\":false,\"vehicle_name\":\"My Tesla Model 3\"}}}"
        let data = Data(dataString.utf8)
        do {
           // if let data = qqData {
                let json: Any = try JSONSerialization.jsonObject(with: data)
                mappedData = Mapper<T>().map(JSONObject: json)
           // }
        } catch let error {
            print(error.localizedDescription)
        }
        //completion(mappedData)
        return mappedData
    }
}

