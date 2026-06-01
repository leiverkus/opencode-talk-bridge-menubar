import XCTest
@testable import TalkBridgeMenubar

final class BridgeRepoValidatorTests: XCTestCase {
    private var repoRoot: URL!
    private var settings: AppSettings!
    private var suiteName: String!

    override func setUpWithError() throws {
        repoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-repo-\(UUID().uuidString)", isDirectory: true)
        suiteName = "validator-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: defaults)
        settings.bridgeRepoPath = repoRoot.path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: repoRoot)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - fixture helpers

    private func makeDir(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func touch(_ url: URL) throws {
        try makeDir(url.deletingLastPathComponent())
        try Data("x".utf8).write(to: url)
    }

    private func createRepoDir() throws { try makeDir(repoRoot) }
    private func createPlistTemplate() throws { try touch(settings.plistTemplateURL) }
    private func createVenvBinary() throws { try touch(settings.venvBinaryURL) }
    private func createEnvFile() throws { try touch(settings.envFileURL) }

    // MARK: - tests

    func testEmptyPathIsAllFalse() {
        settings.bridgeRepoPath = ""
        let v = BridgeRepoValidator.validate(settings)
        XCTAssertFalse(v.repoExists)
        XCTAssertFalse(v.plistTemplateExists)
        XCTAssertFalse(v.venvBinaryExists)
        XCTAssertFalse(v.envFileExists)
        XCTAssertFalse(v.isUsable)
    }

    func testWhitespacePathIsAllFalse() {
        settings.bridgeRepoPath = "   "
        XCTAssertFalse(BridgeRepoValidator.validate(settings).isUsable)
    }

    func testNonexistentRepoIsNotUsable() {
        // repoRoot was never created on disk.
        let v = BridgeRepoValidator.validate(settings)
        XCTAssertFalse(v.repoExists)
        XCTAssertFalse(v.isUsable)
    }

    func testFullyPopulatedRepoIsUsable() throws {
        try createRepoDir()
        try createPlistTemplate()
        try createVenvBinary()
        try createEnvFile()

        let v = BridgeRepoValidator.validate(settings)
        XCTAssertTrue(v.repoExists)
        XCTAssertTrue(v.plistTemplateExists)
        XCTAssertTrue(v.venvBinaryExists)
        XCTAssertTrue(v.envFileExists)
        XCTAssertTrue(v.isUsable)
    }

    func testMissingVenvBinaryIsNotUsable() throws {
        try createRepoDir()
        try createPlistTemplate()
        // no venv binary
        let v = BridgeRepoValidator.validate(settings)
        XCTAssertTrue(v.repoExists)
        XCTAssertTrue(v.plistTemplateExists)
        XCTAssertFalse(v.venvBinaryExists)
        XCTAssertFalse(v.isUsable)
    }

    func testMissingPlistTemplateIsNotUsable() throws {
        try createRepoDir()
        try createVenvBinary()
        // no plist template
        let v = BridgeRepoValidator.validate(settings)
        XCTAssertFalse(v.plistTemplateExists)
        XCTAssertFalse(v.isUsable)
    }

    func testMissingEnvDoesNotBlockUsable() throws {
        try createRepoDir()
        try createPlistTemplate()
        try createVenvBinary()
        // no .env

        let v = BridgeRepoValidator.validate(settings)
        XCTAssertFalse(v.envFileExists)
        XCTAssertTrue(v.isUsable, ".env is recommended but not required for usability")
    }

    func testDirectoryWherePlistExpectedIsNotAFile() throws {
        try createRepoDir()
        try createVenvBinary()
        // create a directory at the plist template path instead of a file
        try makeDir(settings.plistTemplateURL)
        let v = BridgeRepoValidator.validate(settings)
        XCTAssertFalse(v.plistTemplateExists)
        XCTAssertFalse(v.isUsable)
    }
}
