//
//  NetworkSpeedTracker.swift
//  
//
//  Created by Wynn Zhang on 7/2/23.
//

import Foundation

protocol NetworkSpeedTrackable {
    var totalNumberOfBytes: Int { get }
    func numberOfBytesDownloaded(since date: Date) -> Int
    func numberOfBytesDownloaded(over timeInterval: TimeInterval) -> Int
}

struct NetworkSpeedTracker: NetworkSpeedTrackable {
    var totalNumberOfBytes: Int = 0
    
    // TODO: limit number of dataPoints stored
    private var dataPoints: [NetworkSpeedDataPoint] = [NetworkSpeedDataPoint(0)]
    
    mutating func increase(by bytes: Int) {
        totalNumberOfBytes += bytes
        addDataPoint(NetworkSpeedDataPoint(totalNumberOfBytes))
    }
    
    private mutating func addDataPoint(_ dataPoint: NetworkSpeedDataPoint) {
        dataPoints = [dataPoint] + dataPoints
    }
    
    func numberOfBytesDownloaded(since date: Date) -> Int {
        guard let previouslyDataPoint = dataPoints.first(where: { $0.dateRecorded < date }) else {
            return totalNumberOfBytes
        }
        return totalNumberOfBytes - previouslyDataPoint.numberOfBytes
    }
    
    func numberOfBytesDownloaded(over timeInterval: TimeInterval) -> Int  {
        return numberOfBytesDownloaded(since: Date(timeIntervalSinceNow: -timeInterval))
    }
}

struct NetworkSpeedDataPoint: Equatable, Comparable {
    var numberOfBytes: Int
    var dateRecorded: Date
    
    init(_ numberOfBytes: Int, dateRecorded: Date = Date()) {
        self.numberOfBytes = numberOfBytes
        self.dateRecorded = dateRecorded
    }
    
    static func <(lhs: NetworkSpeedDataPoint, rhs: NetworkSpeedDataPoint) -> Bool {
        return lhs.dateRecorded.compare(rhs.dateRecorded) == .orderedAscending
    }
}

class CombinedNetworkSpeedTracker: NetworkSpeedTrackable {
    let trackers: () -> [NetworkSpeedTracker]
    
    init(trackers: @escaping () -> [NetworkSpeedTracker]) {
        self.trackers = trackers
    }
    
    // MARK: - NetworkSpeedTrackable
    
    var totalNumberOfBytes: Int {
        var result = 0
        for tracker in trackers() {
            result += tracker.totalNumberOfBytes
        }
        return result
    }
    
    func numberOfBytesDownloaded(since date: Date) -> Int {
        var result = 0
        for tracker in trackers() {
            result += tracker.numberOfBytesDownloaded(since: date)
        }
        return result
    }
    
    func numberOfBytesDownloaded(over timeInterval: TimeInterval) -> Int {
        var result = 0
        for tracker in trackers() {
            result += tracker.numberOfBytesDownloaded(over: timeInterval)
        }
        return result
    }
}
