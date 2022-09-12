//
//  TeslaStreaming.swift
//  TeslaKit
//
//  Created by David Lüthi on 06.03.21
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import Starscream
import SwiftUI
import TeslaKit
import ObjectMapper
import Combine


public enum TeslaStreamingResult {
    case open
    case result(StreamResult)
    case error(Error)
    case disconnected
}


/**
 Streaming class takes care of the different types of data streaming from Tesla servers
 
 **/
public class TeslaStreaming {  
	private var isConnected = false
    private var socket: WebSocket
    
    public init() {
		var request = URLRequest(url: URL(string: "wss://streaming.vn.teslamotors.com/streaming/")!)
		request.timeoutInterval = 5
        socket = WebSocket(request: request)
    }

    /**
     Open Stream to Tesla Server to receive vehicle data. The token is taken from TeslaAPI

     - parameter vehicle: the vehicle that will receive the command
	 - parameter accessToken: token?.accessToken
     - parameter dataReceived: callback to receive the websocket data
     */
	public func openStream(vehicle: Vehicle, accessToken: String, dataReceived: @escaping (TeslaStreamingResult) -> Void) {
		if !isConnected {
			print("Opening Stream")
			if (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
				self.isConnected = true
				let demoValue = String(Date().timeIntervalSince1970) + ",\(vehicle.driveState.speed),\(vehicle.vehicleState.odometer),\(vehicle.chargeState.batteryLevel),459,175.0,\(vehicle.driveState.latitude),\(vehicle.driveState.longitude),\(vehicle.chargeState.chargerPower),shift,\(vehicle.chargeState.batteryRange),\(vehicle.chargeState.estBatteryRange),175.0"
				dataReceived(TeslaStreamingResult.result(StreamResult(values: demoValue)))
			} else {      
				self.socket.onEvent = { [weak self] event in
					guard let self = self else { return }
					switch event {
					case let .connected(headers):
						self.isConnected = true
						print("websocket is connected: \(headers)")
						DispatchQueue.main.async {
							let encoder = JSONEncoder()
							encoder.outputFormatting = .prettyPrinted
							encoder.dateEncodingStrategy = .secondsSince1970
							if let authMessage = StreamAuthentication(vehicleId: "\(vehicle.vehicleId)", accessToken: accessToken), let string = try? encoder.encode(authMessage) {
								self.socket.write(data: string)
								dataReceived(TeslaStreamingResult.open)
							} else {
								dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: 0, userInfo: ["error" : "Failed to parse authentication data"])))
								self.closeStream(vehicle: vehicle)
							}
						}
					case let .disconnected(reason, code):
						self.isConnected = false
						print("websocket is disconnected: \(reason) with code: \(code)")
						DispatchQueue.main.async {
							dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: Int(code), userInfo: ["error": reason])))
						}
					case let .text(string):
						print("Received text: \(string)")
					case let .binary(data):
						print("Received data: \(data.count) - \(String(data: data, encoding: .utf8) ?? "")")           
						do {
							let json: Any = try JSONSerialization.jsonObject(with: data)
							guard let message = Mapper<StreamMessage>().map(JSONObject: json) else { return }
							DispatchQueue.main.async {
								switch message.messageType {
								case "control:hello":
									print("Stream got hello")
									break
								case "data:update":
									if let values = message.value {
										print("Stream got data: \(values)")
										dataReceived(TeslaStreamingResult.result(message.streamResult))
									}
								case "data:error":
									print("Stream got data error: \(message.value ?? ""), \(message.errorType ?? "")")
									dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: 0, userInfo: [message.value ?? "error": message.errorType ?? ""])))
									break
								default:
									break
								}
							}
						} catch { return }
					case let .ping(ping):
						print("Received ping: \(String(describing: ping))")
						break
					case let .pong(data):
						print("Received pong data")
						DispatchQueue.main.async {
							self.socket.write(pong: data ?? Data())
						}
					case let .viabilityChanged(viability):
						print("Received viabilityChanged: \(viability)")
						break
					case let .reconnectSuggested(reconnect):
						print("Received reconnectSuggested: \(reconnect)") 
						break
					case .cancelled:
						print("Received cancelled")
						self.isConnected = false
					case let .error(error):
						print("Received error:\(String(describing: error))")
						self.isConnected = false
						DispatchQueue.main.async {
							if let e = error as? WSError {
								dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: 0, userInfo: ["error": e.message])))
							} else if let e = error {
								dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: 0, userInfo: ["error": e.localizedDescription])))
							} else {
								dataReceived(TeslaStreamingResult.error(NSError(domain: "TeslaStreamingError", code: 0, userInfo: ["error": "websocket encountered an error"])))
							}
						}
					}
				}
				self.socket.connect()
			}
		} else {
			print("Stream is already open")
		}
    }

    /**
     Stops the stream
     */
    public func closeStream(vehicle: Vehicle) {
		if isConnected {
			if (vehicle.vin?.vinString == "VIN#DEMO_#TESTING"){
				self.isConnected = false
				print("websocket is disconnected")
			}
			self.socket.disconnect()
			print("Stream closed")
		} else {
			print("Stream is already closed")
		}
    }
}

extension TeslaStreaming  {

    public func streamPublisher(vehicle: Vehicle, accessToken: String) -> TeslaStreamingPublisher {
        return TeslaStreamingPublisher(vehicle: vehicle, accessToken: accessToken, stream: self)
    }

    public struct TeslaStreamingPublisher: Publisher, Cancellable {

        public typealias Output = TeslaStreamingResult
        public typealias Failure = Error

        let vehicle: Vehicle
		let accessToken: String
        let stream: TeslaStreaming

        init(vehicle: Vehicle, accessToken: String, stream: TeslaStreaming) {
            self.vehicle = vehicle
			self.accessToken = accessToken
            self.stream = stream
        }

        public func receive<S>(subscriber: S) where S : Subscriber, TeslaStreamingPublisher.Failure == S.Failure, TeslaStreamingPublisher.Output == S.Input {
            stream.openStream(vehicle: vehicle, accessToken: accessToken) { (streamResult: TeslaStreamingResult) in
                switch streamResult {
                    case .open:
                        _ = subscriber.receive(TeslaStreamingResult.open)
                    case .result(let result):
                        _ = subscriber.receive(TeslaStreamingResult.result(result))
                    case .error(let error):
                        _ = subscriber.receive(TeslaStreamingResult.error(error))
                    case .disconnected:
                        _ = subscriber.receive(TeslaStreamingResult.disconnected)
                        subscriber.receive(completion: Subscribers.Completion.finished)
                }
            }
        }

        public func cancel() {
            stream.closeStream(vehicle: vehicle)
        }
    }
}





