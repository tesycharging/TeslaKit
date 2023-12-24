#################
# TeslaKit

#################
# TeslaKit is a framework written in Swift that makes it easy for you to interface with Tesla's mobile API and communicate with your Tesla automobiles.
It has the ability to use the unofficial API or the official API.
The official API is described here: https://developer.tesla.com/docs/fleet-api

#################
# Features
- Authenticate with Tesla's API to obtain an access token
- Retrieve a list of vehicles associated with your Tesla account
- Obtain all data on your vehicle
- Send commands to your vehicle
- Obtain data from nearby charging sites
- Utilizes ObjectMapper for JSON mapping
- includes a mock/demo to be able to release it easily to the app store (works wihtout connected Tesla)
- get user profil of your Tesla account
- plan a trip
- set your trip destination
- streaming from Tesla's websocket
- Summon - Coming soon

#################
# Inspiration
I drive a Tesla Model 3 since 2019. The possiblity to connect to your car and bring some more additional value facinate me.
In 2020, I have officially release my app, called TesyCharging, on the App Store.
In the beginning I have taken the API provided by https://github.com/HamblinSoft/TeslaKit. I continued the work on the API and decided to make it available as open source, so others could build really cool apps too.

#################
# Contributing
Contributions are very welcome.
Before submitting any pull request, please ensure you have run the included tests and they have passed. If you are including new functionality, please write test cases for it as well.

#################
# Installation - Swift Package Manager
To add TeslaKit to a Swift Package Manager based project, add:
<sub>.package(url: "https://github.com/tesycharging/TeslaKit.git", .upToNextMajor(from: "2.1.2")),</sub>
to your Package.swift files dependencies array.

#################
# Usage
Add an ATS exception domain for owner-api.teslamotors.com in your info.plist
```
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>owner-api.teslamotors.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.3</string>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

Add an import statement for TeslaKit into your file
```
import TeslaKit
```    

## TeslaAPI
Create a new TeslaAPI instance with a third-party account at https://developer.tesla.com
```
let teslaAPI = TeslaAPI(clientID: "xxx", client_secret: "yyy", domain: "mydomain.com", redirect_uri: "https://mydomain.com/callback", authorizationScope: [.openid, .offline_access, .user_data, .vehicle_device_data, .vehicle_cmds, .vehicle_charging_cmds])
```
- clientID: Partner application client id.
- client_secret:  Partner application client secret.
- domain: Partner domain used to validate registration flow.
- redirect_uri:  Partner application callback url, spec: rfc6749.
- authorizationScope: list of scopes.

Create a new TeslaAPI instance with the unofficial API
```
let teslaAPI = TeslaAPI()
```
or by setting 
```
teslaAPI.officialAPI = false
```

## generating a partner authentication and generating a third-party token on behalf of the customer
Generates a token to be used for managing a partner's account or devices they own. Generate a token on behalf of a customer. This allows API calls using the scopes granted by the customer.
```
teslaAPI
```
It uses the WebLogin provided by Tesla.

## register an existing account
Registers an existing account before it can be used for general API access. Each application from developer.tesla.com must complete this step.
- 1: Generating a partner authentication token by POST https://auth.tesla.com/oauth2/v3/token
- 2: register by POST https://fleet-api.prd.na.vn.cloud.tesla.com/api/1/partner_accounts
```
Task { @MainActor in
    do {
        if teslaAPI.officialAPI {
            try await teslaAPI.registerThirdPartyAPI()
        }
    } catch (let error) {
    }
}
```

## authentication with your Tesla credentials using the oAuth2 flow with MFA support
Uses the WebLogin provided by Tesla
- 3: Generating a third-party token on behalf of a customer initiate the authorization code flow, direct the customer to an /authorize request by GET https://auth.tesla.com/oauth2/v3/authorize
```
WebLogin(teslaAPI: teslaAPI, result: $result, action: {
    switch result {
    case .success(let token):
        UserDefaults.group.teslatoken = token.toJSONString()
    case .failure(let error):
    }
})
```

## Token reuse
After authentication, store the AuthToken in a safe place. The next time the app starts-up you can reuse the token:
```
if let jsonString = UserDefaults.standard.object(forKey: "tesla.token") as? String, let token = AuthToken.loadToken(jsonString: jsonString) {
    teslaAPI.reuse(token: token)
}
```
## Token refresh
After reusing the token, it might need to be refrehed
```
Task { @MainActor in
    do {
        _ = try await teslaAPI.refreshWebToken()
        UserDefaults.standard.set(teslaAPI.token?.toJSONString(), forKey: "tesla.token")
        UserDefaults.standard.synchronize()                    
    } catch let error {
        //Process error
    }
}
```

## Vehicle List
Obtain a list of vehicles associated with your account
```
Task { @MainActor in
    do {
        let vehicles: [String:Vehicle] = try await teslaAPI.getVehicles()
        //Process some code
    } catch let error {
        //Process error
    }
}
```

## Wake up 
In case the vehicle is in status "asleep" it has to be wake up to request all data from the vehicle
```
Task { @MainActor in
    do {
        _ = try await teslaAPI.wakeUp(vehicle)
        //Process some code
    } catch let error {
        //Process error
    }
}
```
It takes up to 30 seconds after receiving the wakUp call till the vehicle changes it status to "online"

## Mobile Remote Access
Check if mobile remote access is granted to be able to obtain all data from the vehicle. To check if mobile remote access is granted, the vehicle must be in status "online"
```
Task { @MainActor in
    do {
        let mobileAccess = try await teslaAPI.getVehicleMobileAccessState(vehicle)
        if !mobileAccess {
            //restriced to have remote access.
            //Process some code
        } else {
            //Process some code to obtain all data from vehicle
        }
    } catch (let error) {
        //Process error
    }
}
```

## Vehicle Data
Obtain all data for a vehicle
```
Task { @MainActor in
    do {
        guard let current_vehicle = try await teslaAPI.getVehicle(vehicle) else { return }
        //Process some code
    } catch let error {
        //Process error
    }
}
```

Generic approach to obtain all data or specific data, e.g. driveState
```
Task { @MainActor in
    do {
        guard let current_vehicle = try await teslaAPI.getVehicleData(.allStates(vehicleID: vehicle.id)) else { return }
        //Process some code
    } catch let error {
        //Process error
    }
}
```

or specific data, e.g. driveState    
```
Task { @MainActor in
    do {
        guard let driveState = try await teslaAPI.getVehicleData(.driveState(vehicleID: vehicle.id)) else { return }
        //Process some code
    } catch let error {
        //Process error
    }
}
```

## endpoint data
fetches the location data like gps dcoordinates
```
Task { @MainActor in
    do {
        let endpointData: EndpointData = try await teslaAPI.getLEndpoint(id, endpoint: .locationData)
        //Process some code
    } catch (let error) {
        //Process error
    }
}
```

## nearby Charging Sites    
Fetches the nearby charging sites
```
Task { @MainActor in
    do {
        let chargingsites: Chargingsites = try await teslaAPI.getNearbyChargingSites(vehicle)
        //Process some code
    } catch (let error) {
        //Process error
    }
}
```

## Send Command
Send a command to a vehicle
```
Task { @MainActor in
    do {
        _ = try await teslaAPI.setCommand(vehicle, command: Command.flashLights)
        //Process some code
    } catch let error {
        //Process error
    }
}
```

Send a command to a vehicle with request parameters
```
Task { @MainActor in
    do {
        _ = try await teslaAPI.setCommand(vehicle, command: Command.sentryMode, parameter: SentryMode(isOn: true))
    } catch let error {
        //Process error
    }
}
```

# get Tesla account profile
Send a command to tesla.com when you are authenticated
```
Task { @MainActor in
    do {
        guard let user = try await teslaAPI.getUser()
    } catch let error {
        //Process error
    }
}
```

# plan a trip
Send a command to tesla.com when you are authenticated. The result tells how many charging stops, how long it takes, etc.
```
Task { @MainActor in
    do {
        guard let tripplan = try await teslaAPI.tripplan(vehicle, destination: Location(lat: 37.485767, long: -122.240207)
    } catch let error {
        //Process error
    }
}
```
or define your battery level and location at start of the trip
```
Task { @MainActor in
    do {
        guard let tripplan = try await teslaAPI.tripplan(vehicle, destination: Location(lat: 37.485767, long: -122.240207), origin: Location = Location(lat: 37.79307,long: -125.108), origin_soe: 0.5)
    } catch let error {
        //Process error
    }
}
```

# set your trip destination
```
Task { @MainActor in
    do {
        _ = try await teslaAPI.setCommand(vehicle, command: Command.share, parameter:  ShareParam(latitude: 37.485767, longitude: -122.240207))
    } catch let error {
        //Process error
    }
}
```

# Streaming from Tesla's Websocket
Receive a continous stream
## start stream
e.g. at onAppear of a View
```
var stream: TeslaStreaming = TeslaStreaming()
@State var streamResult : StreamResult = StreamResult(values: "")
@State var streaming = false

func startStream() {
    if !streaming {
        _ = stream.streamPublisher(vehicle: vehicle, accessToken: teslaAPI.token?.accessToken ?? "").sink(receiveCompletion: { (completion) in
        }) { (result) in
            switch result {
            case .error(let error):
                print(error.localizedDescription)
                stream.closeStream(vehicle: vehicle)
                streaming = false                
            case .result(let result):
                self.streamResult = result
            case .disconnected:
                break
            case .open:
                print("open")
            }
        }
        self.streaming = true
    }
}
```
## stop stream
e.g. at onDisappear of a View
```
func stopStream() {
    stream.closeStream(vehicle: vehicle)
    streaming = false
}
```

#################
# Author
David Lüthi, tesyios@gmail.com

#################
# License
This project is licensed under the terms of the MIT license.

This project is in no way affiliated with Tesla Inc. This project is open source under the MIT license, which means you have full access to the source code and can modify it to fit your own needs.

The base of the code has Copyright (c) 2018 HamblinSoft <Jaren.Hamblin@HamblinSoft.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

