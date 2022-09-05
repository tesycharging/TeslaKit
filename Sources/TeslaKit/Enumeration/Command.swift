//
//  Command.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 1/10/18.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

/// All commands that can be sent to a vehicle
public enum Command: String, CaseIterable, CustomStringConvertible {

    /// Sets valet mode on or off with a PIN to disable it from within the car. Reuses last PIN from previous valet session. Valet Mode limits the car's top speed to 70MPH and 80kW of acceleration power. It also disables Homelink, Bluetooth and Wifi settings, and the ability to disable mobile access to the car. It also hides your favorites, home, and work locations in navigation.
    case setValetMode = "set_valet_mode"

    /// Resets the PIN set for valet mode, if set.
    case resetValetPin = "reset_valet_pin"

    /// Opens the charge port.
    case openChargePort = "charge_port_door_open"

    /// Closes the charge port.
    case closeChargePort = "charge_port_door_close"

    /// Set the charge mode to standard (90% under the new percentage system introduced in 4.5).
    case setChargeLimitToStandard = "charge_standard"

    /// Set the charge mode to max range (100% under the new percentage system introduced in 4.5). Use sparingly!
    case setChargeLimitToMaxRange = "charge_max_range"

    /// Set the charge limit to a custom percentage.
    case setChargeLimit = "set_charge_limit"

    /// Start charging. Must be plugged in, have power available, and not have reached your charge limit.
    case startCharging = "charge_start"

    /// Stop charging. Must already be charging.
    case stopCharging = "charge_stop"

    /// Flash the lights once.
    case flashLights = "flash_lights"

    /// Honk the horn once.
    case honkHorn = "honk_horn"

    /// Unlock the car's doors.
    case unlockDoors = "door_unlock"

    /// Lock the car's doors.
    case lockDoors = "door_lock"

    /// Set the temperature target for the HVAC system.
    case setTemperature = "set_temps"

    /// Start the climate control system. Will cool or heat automatically, depending on set temperature.
    case startHVAC = "auto_conditioning_start"

    /// Stop the climate control system.
    case stopHVAC = "auto_conditioning_stop"

    /// Controls the car's panoramic roof, if installed.
    case movePanoRoof = "sun_roof_control"

    /// Start the car for keyless driving. Must start driving within 2 minutes of issuing this request.
    case remoteStart = "remote_start_drive"

    /// Open the trunk or frunk. Currently inoperable.
    case openTrunk = "actuate_trunk"
    
    /// Opens and closes the configured Homelink garage door of the vehicle. Keep in mind this is a toggle and the garage door state is unknown - a major limitation of Homelink
    //    case triggerHomelink = "trigger_homelink"
    ///
    ///    case frontDefrosterOn = "front_defrost_on"
    ///
    ///    case frontDefrosterOff = "front_defrost_off"
    ///
    ///    case rearDefrosterOn = "rear_defrost_on"
    ///
    ///    case rearDefrosterOff = "rear_defrost_off"
    ///
        case setPreconditioningMax = "set_preconditioning_max"
    case speedLimitActivate = "speed_limit_activate"

    ///
    case speedLimitDeactivate = "speed_limit_deactivate"

    ///
    case speedLimitClearPIN = "speed_limit_clear_pin"

    /// Set Speed Limit
    case setSpeedLimit = "speed_limit_set_limit"

    // MARK: - Media Player
    ///
    case togglePlayback = "media_toggle_playback"

    ///
    case nextTrack = "media_next_track"

    ///
    case previousTrack = "media_prev_track"

    ///
    case nextFavorite = "media_next_fav"

    ///
    case previousFavorite = "media_prev_fav"

    ///
    case volumeUp = "media_volume_up"

    ///
    case volumeDown = "media_volume_down"

    // MARK: - Navigation
    ///
    case navigationRequest = "navigation_request"

    // MARK: - Software Update
    ///
    case scheduleSoftwareUpdate = "schedule_software_update"

    ///
    case cancelSoftwareUpdate = "cancel_software_update"

    // MARK: - Seat/Wheel Heaters
    ///
    case remoteSeatHeater = "remote_seat_heater_request"

    ///
    case remoteSteeringWheelHeater = "remote_steering_wheel_heater_request"

    // MARK: - Sentry Mode
    ///
    case sentryMode = "set_sentry_mode"
    
    case homelink = "trigger_homelink"
    
    //// Controls the windows. Will vent or close all windows simultaneously.
    //// lat and lon values must be near the current location of the car for close operation to succeed. 
    //// For vent, the lat and lon values are ignored, and may both be 0 (which has been observed from the app itself).
    case openWindow = "window_control"

    ///
    public var description: String {
        return self.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    ///
    public var path: String {
        return "command/" + self.rawValue
    }
}
