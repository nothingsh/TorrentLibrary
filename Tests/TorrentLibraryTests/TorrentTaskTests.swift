//
//  File.swift
//
//
//  Created by Wynn Zhang on 8/20/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

class TorrentListenerSocketStub: TorrentListenerSocket {
    init(model: TorrentModel) {
        let clientID = Data(repeating: 1, count: 20)
        super.init(infoHash: model.infoHashSHA1, clientID: clientID)
    }
    
    var startListeningCalled = false
    override func startListening() {
        startListeningCalled = true
    }
}

class TorrentPeerManagerStub: TorrentPeerManager {
    init(model: TorrentModel) {
        let clientID = Data(repeating: 1, count: 20)
        super.init(clientID: clientID, infoHash: model.infoHashSHA1, bitFieldSize: model.info.pieces.count)
    }
    
    var stopPeersConnectionCalled = false
    override func stopPeersConnection() {
        stopPeersConnectionCalled = true
    }
    
    var resumePeersConnectionsCalled = false
    override func resumePeersConnections() {
        resumePeersConnectionsCalled = true
    }
    
    var addPeersCalled = false
    var addPeersParameter: [TorrentPeerInfo]? = nil
    override func addPeers(withInfo peerInfos: [TorrentPeerInfo]) {
        addPeersCalled = true
        addPeersParameter = peerInfos
    }
    
    var addPeerCalled = false
    var addPeerParameter: TorrentPeer? = nil
    override func addPeer(_ peer: TorrentPeer) {
        addPeerCalled = true
        addPeerParameter = peer
    }
}

class TorrentPeerProviderManagerStub: TorrentPeerProviderManager {
    let tracker = TorrentTrackerStub()
    
    init(model: TorrentModel) {
        let clientID = Data(repeating: 1, count: 20)
        super.init(model: model, peerID: clientID)
    }
    
    var startPeersFetchingCalled = false
    override func startPeersFetching() {
        startPeersFetchingCalled = true
    }
    
    var stopPeersFetchingCalled = false
    override func stopPeersFetching() {
        stopPeersFetchingCalled = true
    }
    
    var resumePeersFetchingCalled = false
    override func resumePeersFetching() {
        resumePeersFetchingCalled = true
    }
    
    var fetchMorePeersImediatlyCalled = false
    override func fetchMorePeersImediatly() {
        fetchMorePeersImediatlyCalled = true
    }
}

class TorrentProgressManagerStub: TorrentProgressManager {
    let fileHandle: FileHandleFake
    
    init(model: TorrentModel) {
        fileHandle = FileHandleFake(data: Data(repeating: 0, count: model.info.length ?? 0))
        let fileManager = TorrentFileManager(torrent: model, rootDirectory: "/", fileHandles: [fileHandle])
        let progress = TorrentProgress(size: model.info.pieces.count)
        super.init(fileManager: fileManager, progress: progress)
    }
    
    var testProgress = TorrentProgress(size: 1)
    override var progress: TorrentProgress {
        return testProgress
    }
    
    var setDownloadedPieceCalled = false
    var setDownloadedPieceParameters: (piece: Data, pieceIndex: Int)?
    override func setDownloadedPiece(_ piece: Data, pieceIndex: Int) {
        setDownloadedPieceCalled = true
        setDownloadedPieceParameters = (piece, pieceIndex)
    }
    
    var setLostPieceCalled = false
    var setLostPieceIndex: Int = 0
    override func setLostPiece(at index: Int) {
        setLostPieceCalled = true
        setLostPieceIndex = index
    }
    
    var getNextPieceToDownloadCalled = false
    var getNextPieceToDownloadParameter: BitField?
    var getNextPieceToDownloadResult: TorrentPieceRequest?
    override func getNextPieceToDownload(from availablePieces: BitField) -> TorrentPieceRequest? {
        getNextPieceToDownloadCalled = true
        getNextPieceToDownloadParameter = availablePieces
        return getNextPieceToDownloadResult
    }
}

final class TorrentTaskTests: XCTestCase {
    let pathRoot = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
    
    let model: TorrentModel = {
        let path = Bundle.module.path(forResource: "TestText", ofType: "torrent")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        return try! TorrentModel.decode(data: data)
    }()
    
    let finalData: Data = {
        let path = Bundle.module.path(forResource: "text", ofType: "txt")
        return try! Data(contentsOf: URL(fileURLWithPath: path!))
    }()
    
    var listenerSocket: TorrentListenerSocketStub!
    var peerManager: TorrentPeerManagerStub!
    var peerProviderManager: TorrentPeerProviderManagerStub!
    var progressManager: TorrentProgressManagerStub!
    var sut: TorrentTask!
    
    override func setUp() {
        super.setUp()
        progressManager = TorrentProgressManagerStub(model: model)
        listenerSocket = TorrentListenerSocketStub(model: model)
        peerManager = TorrentPeerManagerStub(model: model)
        peerProviderManager = TorrentPeerProviderManagerStub(model: model)
        
        sut = TorrentTask(model: model, listenerSocket: listenerSocket, peerManager: peerManager, peerProviderManager: peerProviderManager, progressManager: progressManager)
    }
    
    func test_dependanciesCreated() {
        XCTAssertEqual(sut.torrentModel.infoHashSHA1, model.infoHashSHA1)
        XCTAssert(sut.listenerSocket.delegate === sut)
        XCTAssert(sut.peerProvider.delegate === sut)
        XCTAssert(sut.peerManager.delegate === sut)
    }
    
    func test_torrentServerStartsListeningOnTorrentStart() {
        sut.startTask()
        XCTAssert(listenerSocket.startListeningCalled)
    }
    
    func test_trackerAnnounceOnTorrentStart() {
        sut.startTask()
        XCTAssert(peerProviderManager.startPeersFetchingCalled)
    }
    
    func test_status() {
        XCTAssertEqual(sut.status, .stopped)
        
        sut.startTask()
        XCTAssertEqual(sut.status, .started)
        
        progressManager.testProgress.setCurrentlyDownloading(piece: 0)
        progressManager.testProgress.finishedDownloading(piece: 0)
        sut.torrentPeerManager(peerManager, downloadedPieceAtIndex: 0, piece: finalData)
        XCTAssertEqual(sut.status, .completed)
    }
    
    func test_whenTorrentAlreadyDownloaded_statusIsCompletedOnStart() {
        progressManager.testProgress.setCurrentlyDownloading(piece: 0)
        progressManager.testProgress.finishedDownloading(piece: 0)
        sut.startTask()
        XCTAssertEqual(sut.status, .completed)
    }
    
    func test_newPeersFromTrackerAreGivenToPeersManager() {
        // Given
        let peers = [TorrentPeerInfo(ip: "127.0.0.1", port: 123)]
        
        // When
        sut.torrentPeerProvider(peerProviderManager, newPeers: peers)
        
        // Then
        XCTAssert(peerManager.addPeersCalled)
        if let addPeersParameter = peerManager.addPeersParameter {
            XCTAssertEqual(addPeersParameter, peers)
        }
    }
    
    func test_announceInfoComesFromProgress() {
        // Given
        let pieceLength = model.info.pieceLength
        
        var progress = TorrentProgress(size: 5)
        
        progress.setCurrentlyDownloading(piece: 0)
        progress.finishedDownloading(piece: 0)
        
        progress.setCurrentlyDownloading(piece: 1)
        progress.finishedDownloading(piece: 1)
        
        progressManager.testProgress = progress
        
        // When
        let result = sut.torrentPeerProviderManagerAnnonuceInfo(peerProviderManager)
        
        // Then
        XCTAssertEqual(result.numberOfBytesDownloaded, pieceLength*2)
        XCTAssertEqual(result.numberOfBytesRemaining, pieceLength*3)
        XCTAssertEqual(result.numberOfBytesUploaded, 0)
    }
    
    func test_bitFieldForHandshakeComesFromProgress() {
        // Given
        var progress = TorrentProgress(size: 5)
        
        progress.setCurrentlyDownloading(piece: 0)
        progress.finishedDownloading(piece: 0)
        
        progress.setCurrentlyDownloading(piece: 1)
        progress.finishedDownloading(piece: 1)
        
        progressManager.testProgress = progress
        
        // When
        let result = sut.torrentPeerManagerCurrentBitfieldForHandshake(peerManager)
        
        // Then
        XCTAssertEqual(result, progress.bitField)
    }
    
    func test_progressNotifiedOnDownloadedPiece() {
        sut.torrentPeerManager(peerManager, downloadedPieceAtIndex: 123, piece: finalData)
        
        XCTAssert(progressManager.setDownloadedPieceCalled)
        if let setDownloadedPieceParameters = progressManager.setDownloadedPieceParameters {
            XCTAssertEqual(setDownloadedPieceParameters.piece, finalData)
            XCTAssertEqual(setDownloadedPieceParameters.pieceIndex, 123)
        }
    }
    
    func test_progressNotifiedOnLostPiece() {
        sut.torrentPeerManager(peerManager, failedToGetPieceAtIndex: 123)
        
        XCTAssert(progressManager.setLostPieceCalled)
        XCTAssertEqual(progressManager.setLostPieceIndex, 123)
    }
    
    func test_nextPieceAvailableComesFromProgress() {
        var bitField = BitField(size: 5)
        bitField.setBit(at: 3)
        
        let expected = TorrentPieceRequest(pieceIndex: 1, size: 2, checksum: Data([2]))
        progressManager.getNextPieceToDownloadResult = expected
        
        guard let result = sut.torrentPeerManager(peerManager, nextPieceFromAvailable: bitField) else {
            XCTFail()
            return
        }
        
        XCTAssert(progressManager.getNextPieceToDownloadCalled)
        XCTAssertEqual(progressManager.getNextPieceToDownloadParameter!, bitField)
        XCTAssertEqual(result.pieceIndex, expected.pieceIndex)
        XCTAssertEqual(result.size, expected.size)
        XCTAssertEqual(result.checksum, expected.checksum)
    }
    
    func test_pieceForUploadComesFromFileManager() {
        progressManager.fileHandle.seek(toFileOffset: 0)
        progressManager.fileHandle.write(finalData)
        let result = sut.torrentPeerManager(peerManager, peerRequiresPieceAtIndex: 0)
        XCTAssertEqual(result, finalData)
    }
    
    func test_peersConnectingFromServerAreAddedToPeerManager() {
        // Given
        let peer = createFakePeer()
        
        // When
        sut.torrentListenSocket(listenerSocket, connectedToPeer: peer)
        
        // Then
        XCTAssert(peerManager.addPeerCalled)
        if let addPeerParameter = peerManager.addPeerParameter {
            XCTAssert(addPeerParameter === peer)
        }
    }
    
    func createFakePeer() -> TorrentPeer {
        let peerInfo = TorrentPeerInfo(ip: "127.0.0.1", port: 123)
        let communicator = TorrentPeerCommunicatorStub(peerInfo: peerInfo, infoHash: model.infoHashSHA1)
        return TorrentPeerFake(peerInfo: peerInfo,
                               bitFieldSize: model.info.pieces.count,
                               communicator: communicator)
    }
    
    func test_currentProgressForTorrentServer() {
        // Given
        var progress = TorrentProgress(size: 5)
        
        progress.setCurrentlyDownloading(piece: 0)
        progress.finishedDownloading(piece: 0)
        
        progress.setCurrentlyDownloading(piece: 1)
        progress.finishedDownloading(piece: 1)
        
        progressManager.testProgress = progress
        
        // When
        let result = sut.currentProgress(for: listenerSocket)
        
        // Then
        XCTAssertEqual(result, progress.bitField)
    }
}
