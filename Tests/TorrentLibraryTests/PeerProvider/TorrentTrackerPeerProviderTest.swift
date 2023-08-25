//
//  TorrentTrackerPeerProviderTest.swift
//  
//
//  Created by Wynn Zhang on 8/20/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

class TorrentTrackerStub: TorrentTrackerProtocol {
    weak var delegate: TorrentTrackerDelegate?
    
    var announceClientCalled = false
    var announceClientParameters: (peerId: String,
    port: UInt16,
    event: TorrentTrackerEvent,
    infoHash: Data,
    numberOfBytesRemaining: Int,
    numberOfBytesUploaded: Int,
    numberOfBytesDownloaded: Int,
    numberOfPeersToFetch: Int)?
    
    var onAnnounceClient: (()->Void)?
    func announceClient(with peerId: String,
                        port: UInt16,
                        event: TorrentTrackerEvent,
                        infoHash: Data,
                        numberOfBytesRemaining: Int,
                        numberOfBytesUploaded: Int,
                        numberOfBytesDownloaded: Int,
                        numberOfPeersToFetch: Int) {
        announceClientCalled = true
        announceClientParameters = (peerId,
                                    port,
                                    event,
                                    infoHash,
                                    numberOfBytesRemaining,
                                    numberOfBytesUploaded,
                                    numberOfBytesDownloaded,
                                    numberOfPeersToFetch)
        onAnnounceClient?()
    }
}

class TorrentTrackerPeerProviderDelegateStub: TorrentTrackerPeerProviderDelegate {
    
    func torrentTrackerManager(_ sender: TorrentTrackerPeerProvider, gotNewPeers peers: [TorrentPeerInfo]) {
        
    }
    
    var torrentTrackerManagerAnnonuceInfoResult = TorrentTrackerManagerAnnonuceInfo(numberOfBytesRemaining: 0, numberOfBytesUploaded: 0, numberOfBytesDownloaded: 0, numberOfPeersToFetch: 0)
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerPeerProvider) -> TorrentTrackerManagerAnnonuceInfo {
        return torrentTrackerManagerAnnonuceInfoResult
    }
}

final class TorrentTrackerPeerProviderTest: XCTestCase {
    let model: TorrentModel = {
        let bundle = Bundle.module
        
        let torrentURL = bundle.url(forResource: "TrackerManagerTests", withExtension: "torrent")
        let data = try! Data(contentsOf: torrentURL!)
        return try! TorrentModel.decode(data: data)
    }()
    
    let clientId = "-BD0000-bxa]N#IRKqv`"
    let clientIdData = "-BD0000-bxa]N#IRKqv`".data(using: .ascii)!
    let listeningPort: UInt16 = 123
    
    let announceInfo = TorrentTrackerManagerAnnonuceInfo(numberOfBytesRemaining: 1,
                                                         numberOfBytesUploaded: 2,
                                                         numberOfBytesDownloaded: 3,
                                                         numberOfPeersToFetch: 4)
    
    func test_createsTrackers() {
        let sut = TorrentTrackerPeerProvider(torrentModel: model, peerID: clientIdData, port: listeningPort)
        
        XCTAssertEqual(sut.trackers.count, 2)
        
        guard let httpTracker = sut.trackers.first as? TorrentHTTPTracker else {
            XCTFail("Didn't parse HTTP tracker")
            return
        }
        
        guard let udpTracker = sut.trackers.last as? TorrentUDPTracker else {
            XCTFail("Didn't parse UDP tracker")
            return
        }
        
        guard let httpAnnounceURL = URL(string: model.announceList[0][0]) else {
            XCTFail("Didn't parse http announce url: \(model.announceList[0][0])")
            return
        }
        let httpsScheme = httpAnnounceURL.bySettingScheme(to: "https")
        XCTAssertEqual(httpTracker.announce, httpsScheme)
        
        guard let udpAnnounceURL = URL(string: model.announceList[0][1]) else {
            XCTFail("Didn't parse udp announce url: \(model.announceList[0][0])")
            return
        }
        XCTAssertEqual(udpTracker.announce, udpAnnounceURL)
        
        XCTAssert(httpTracker.delegate === sut)
        XCTAssert(udpTracker.delegate === sut)
    }
    
    func test_startWillAnnounceToTrackers() {
        
        // Given
        let tracker = TorrentTrackerStub()
        let delegate = TorrentTrackerPeerProviderDelegateStub()
        
        let sut = TorrentTrackerPeerProvider(torrentModel: model,
                                        peerID: clientIdData,
                                        port: listeningPort,
                                        trackers: [tracker])
        
        delegate.torrentTrackerManagerAnnonuceInfoResult = announceInfo
        sut.delegate = delegate
        
        // When
        sut.startTrackersAccess()
        
        // Then
        XCTAssert(tracker.announceClientCalled)
        
        guard let announceClientParameters = tracker.announceClientParameters else {
            XCTFail()
            return
        }
        XCTAssertEqual(announceClientParameters.peerId, clientId)
        XCTAssertEqual(announceClientParameters.port, listeningPort)
        XCTAssertEqual(announceClientParameters.event, .started)
        XCTAssertEqual(announceClientParameters.infoHash, model.infoHashSHA1)
        XCTAssertEqual(announceClientParameters.numberOfBytesRemaining, announceInfo.numberOfBytesRemaining)
        XCTAssertEqual(announceClientParameters.numberOfBytesUploaded, announceInfo.numberOfBytesUploaded)
        XCTAssertEqual(announceClientParameters.numberOfBytesDownloaded, announceInfo.numberOfBytesDownloaded)
        XCTAssertEqual(announceClientParameters.numberOfPeersToFetch, announceInfo.numberOfPeersToFetch)
    }
    
    func test_announceRepeats() {
        
        // Given
        let tracker = TorrentTrackerStub()
        let delegate = TorrentTrackerPeerProviderDelegateStub()
        
        let sut = TorrentTrackerPeerProvider(torrentModel: model,
                                        peerID: clientIdData,
                                        port: listeningPort,
                                        trackers: [tracker])
        
        sut.delegate = delegate
        sut.announceTimeInterval = 0
        
        // When
        sut.startTrackersAccess()
        
        // Then
        let expectation = self.expectation(description: "Announce is repeatedly called")
        tracker.onAnnounceClient = {
            tracker.onAnnounceClient = nil
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.1)
    }
    
    func test_canForceReAnnounce_resetsAnnounceTimer() {
        
        // Given
        let tracker = TorrentTrackerStub()
        let delegate = TorrentTrackerPeerProviderDelegateStub()
        let sut = TorrentTrackerPeerProvider(torrentModel: model,
                                        peerID: clientIdData,
                                        port: listeningPort,
                                        trackers: [tracker])
        
        sut.delegate = delegate
        sut.announceTimeInterval = 600
        sut.startTrackersAccess()
        
        // Then
        let expectation = self.expectation(description: "Announce is repeatedly called")
        tracker.onAnnounceClient = {
            tracker.onAnnounceClient = nil
            expectation.fulfill()
        }
        
        // When
        sut.forceRestart()
        waitForExpectations(timeout: 0.1)
    }
}

extension URL {
    func bySettingScheme(to scheme: String) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.scheme = scheme
        return components.url!
    }
}

#if XCODE_BUILD
extension Foundation.Bundle {
    
    /// Returns resource bundle as a `Bundle`.
    /// Requires Xcode copy phase to locate files into `ExecutableName.bundle`;
    /// or `ExecutableNameTests.bundle` for test resources
    static var module: Bundle = {
        var thisModuleName = "CLIQuickstartLib"
        var url = Bundle.main.bundleURL
        
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            url = bundle.bundleURL.deletingLastPathComponent()
            thisModuleName = thisModuleName.appending("Tests")
        }
        
        url = url.appendingPathComponent("\(thisModuleName).bundle")
        
        guard let bundle = Bundle(url: url) else {
            fatalError("Foundation.Bundle.module could not load resource bundle: \(url.path)")
        }
        
        return bundle
    }()
    
    /// Directory containing resource bundle
    static var moduleDir: URL = {
        var url = Bundle.main.bundleURL
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            // remove 'ExecutableNameTests.xctest' path component
            url = bundle.bundleURL.deletingLastPathComponent()
        }
        return url
    }()
    
}
#endif
