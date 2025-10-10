//
//  hopitTests.swift
//  hopitTests
//
//  Created by Michael A Edgcumbe on 9/29/25.
//

import Testing
@testable import hopit
import AVFoundation
import UIKit

@MainActor
@Suite("StoryRabbitController crash safety tests")
struct StoryRabbitControllerTests {

    @Test("buildModel handles missing resources safely")
    func buildModelHandlesMissingResources() async throws {
        let controller = await StoryRabbitController(playerState: .loading, backgroundTask: .invalid)

        // Simulate missing bundle resources
        controller.generatingAudioURL0 = nil
        controller.generatingAudioURL1 = nil
        controller.generatingAudioURL2 = nil
        controller.generatingAudioURL3 = nil
        controller.generatingAudioURL4 = nil

        controller.buildModel()
        controller.repeatLocalFile()

        #expect(controller.audioPlayer != nil, "Audio player should be initialized even if resources are missing.")
        #expect(controller.playerState == .loading, "Player should remain in loading state when only local loop is intended.")
    }

    @Test("sendPlayerProgress returns sane defaults when streaming player is nil")
    func sendPlayerProgressDefaultsWhenStreamingNil() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        // Enable streaming but remove the streaming player to simulate edge case
        StoryRabbitController.STREAMING_ENABLED = true
        controller.isNewRabbitHole = true
        controller.streamAudioPlayer = nil

        let progress = controller.sendPlayerProgress()
        #expect(progress != nil, "Progress dictionary should be returned.")
        #expect(progress?["playerState"] as? String == controller.playerState.rawValue)
        #expect(progress?["playerTime"] is Int, "playerTime should be present and an Int.")
    }

    @Test("getCurrentChapter returns nil when prerequisites missing")
    func getCurrentChapterReturnsNilWithoutPrereqs() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        controller.rabbithole = nil
        controller.level = nil

        #expect(controller.getCurrentChapter() == nil, "Should safely return nil instead of asserting/crashing.")
    }

    @Test("getNextChapter returns nil when out of bounds or missing")
    func getNextChapterReturnsNilWhenOutOfBounds() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        controller.rabbithole = nil
        controller.level = 0

        #expect(controller.getNextChapter() == nil, "Should safely return nil when data is missing.")
    }

    @Test("stop is safe when streamAudioPlayer is nil")
    func stopSafeWhenStreamNil() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        controller.streamAudioPlayer = nil
        controller.level = 3

        controller.stop()

        #expect(controller.level == nil, "Level should be cleared on stop.")
        #expect(controller.chapter == nil, "Chapter should be cleared on stop.")
    }

    @Test("addBoundaryTimeObserver is safe without current item")
    func boundaryTimeObserverSafeWithoutItem() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        controller.audioPlayer = AVQueuePlayer() // No items

        controller.addBoundaryTimeObserver()

        // If we got here, it didn't crash. That's success for this edge case.
        #expect(true)
    }

    @Test("playRemoteFile initializes player if needed")
    func playRemoteInitializesPlayer() async throws {
        let controller = StoryRabbitController(playerState: .loading, backgroundTask: .invalid)
        controller.audioPlayer = nil

        let url = URL(string: "https://example.com/audio.mp3")!
        controller.playRemoteFile(url: url)

        // Allow async dispatch to run
        try await Task.sleep(nanoseconds: 1_800_000_000)

        #expect(controller.audioPlayer != nil, "playRemoteFile should ensure an audio player exists.")
    }
}

