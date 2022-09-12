#################
# TeslaKit

#################
# TeslaKit is a framework written in Swift that makes it easy for you to interface with Tesla's mobile API and communicate with your Tesla automobiles.

#################
# Features
- Authenticate with Tesla's API to obtain an access token
- Retrieve a list of vehicles associated with your Tesla account
- Obtain all data on your vehicle
- Send commands to your vehicle
- Obtain data from nearby charging sites
- Utilizes ObjectMapper for JSON mapping
- includes a mock/demo to be able to release it easily to the app store (works wihtout connected Tesla)
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
<sub>.package(url: "https://github.com/tesycharging/TeslaKit.git", .upToNextMajor(from: "2.0.0")),</sub>
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
			<string>TLSv3.0</string>
			<key>NSExceptionAllowsInsecureHTTPLoads</key>
			<true/>
		</dict>
	</dict>
</dict>
```

Add an import statement for TeslaKit into your file
	import TeslaKit

## TeslaAPI
Create a new TeslaAPI instance
Default:
```
let teslaAPI = TeslaAPI()
```
Debug Mode:
```
let teslaAPI = TeslaAPI(debuggingEnabled = true)
```
Demo Mode:
```
let teslaAPI = TeslaAPI(demoMode = true)
```
Add Mock to your vehicles list
```
let teslaAPI = TeslaAPI(addDemoVehicle = true)
```

## authentication with your Tesla credentials using the oAuth2 flow with MFA support
Uses the WebLogin provided by Tesla
```
WebLogin(teslaAPI: teslaAPI, action: {
	UserDefaults.standard.set(teslaAPI.token?.toJSONString(), forKey: "tesla.token")
	UserDefaults.standard.synchronize()
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

## Streaming from Tesla's Websocket
Receive a continous stream
# start stream
e.g. at onAppear of a View
```
var stream: TeslaStreaming = TeslaStreaming()
@State var streamResult : StreamResult = StreamResult(value: "")
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
# stop stream
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
