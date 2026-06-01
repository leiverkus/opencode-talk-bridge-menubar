import XCTest
@testable import TalkBridgeMenubar

final class BridgeSetupValidatorTests: XCTestCase {
    private var root: URL!
    private var settings: AppSettings!
    private var suiteName: String!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("setup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        suiteName = "setup-validator-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: defaults)
        // point binary + config dir into the temp tree
        settings.bridgeBinaryPath = root.appendingPathComponent("bin/opencode-talk-bridge").path
        settings.configDirPath = root.appendingPathComponent("config").path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - fixtures

    private func makeExecutable(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func makeNonExecutableFile(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    private func makeConfigDir() throws {
        try FileManager.default.createDirectory(
            at: settings.configDirURL, withIntermediateDirectories: true)
    }

    private func makeEnv() throws {
        try makeConfigDir()
        try Data("NC_URL=x\n".utf8).write(to: settings.envFileURL)
    }

    // MARK: - tests

    func testEmptyBinaryPathIsNotUsable() {
        settings.bridgeBinaryPath = ""
        let v = BridgeSetupValidator.validate(settings)
        XCTAssertFalse(v.binaryExists)
        XCTAssertFalse(v.isUsable)
    }

    func testWhitespaceBinaryPathIsNotUsable() {
        settings.bridgeBinaryPath = "   "
        XCTAssertFalse(BridgeSetupValidator.validate(settings).isUsable)
    }

    func testMissingBinaryIsNotUsable() {
        let v = BridgeSetupValidator.validate(settings)
        XCTAssertFalse(v.binaryExists)
        XCTAssertFalse(v.isUsable)
    }

    func testNonExecutableBinaryIsNotUsable() throws {
        try makeNonExecutableFile(settings.bridgeBinaryURL)
        let v = BridgeSetupValidator.validate(settings)
        XCTAssertFalse(v.binaryExists, "a non-executable file must not count")
        XCTAssertFalse(v.isUsable)
    }

    func testExecutableBinaryIsUsable() throws {
        try makeExecutable(settings.bridgeBinaryURL)
        let v = BridgeSetupValidator.validate(settings)
        XCTAssertTrue(v.binaryExists)
        XCTAssertTrue(v.isUsable, "config dir is created on install, so binary alone suffices")
    }

    func testConfigDirDetected() throws {
        try makeExecutable(settings.bridgeBinaryURL)
        XCTAssertFalse(BridgeSetupValidator.validate(settings).configDirExists)
        try makeConfigDir()
        XCTAssertTrue(BridgeSetupValidator.validate(settings).configDirExists)
    }

    func testEnvDetectedButOptional() throws {
        try makeExecutable(settings.bridgeBinaryURL)
        try makeConfigDir()
        XCTAssertFalse(BridgeSetupValidator.validate(settings).envFileExists)
        XCTAssertTrue(BridgeSetupValidator.validate(settings).isUsable)
        try makeEnv()
        let v = BridgeSetupValidator.validate(settings)
        XCTAssertTrue(v.envFileExists)
        XCTAssertTrue(v.isUsable)
    }

    func testDirectoryAtBinaryPathIsNotExecutableFile() throws {
        try makeConfigDir()
        try FileManager.default.createDirectory(
            at: settings.bridgeBinaryURL, withIntermediateDirectories: true)
        XCTAssertFalse(BridgeSetupValidator.validate(settings).binaryExists)
    }
}
