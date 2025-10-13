//
//  NowPlayingQueueView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/5/25.
//

import SwiftUI
import Combine
import AVKit
import MediaPlayer
import Nuke
import NukeUI

// MARK: - Model

//struct Track: Identifiable, Hashable {
//    let id = UUID()
//    let url: URL
//    let title: String
//    let artist: String
//    let artwork: UIImage?
//}

// MARK: - Apple Music–style Now Playing (with queue)

struct NowPlayingQueueView: View {
    @Binding var selectedTour:Tour?
    @Binding var selectedPOI: POI
    @Binding var currentPOIs: [POI] // Add this to access all POIs
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var player = QueuePlayerEngine(
        playlist: [],
        startAt: 0
    )

    @State private var showingQueue = false

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack(alignment:.top) {
                    ZStack(alignment: .center) {
                        Color.clear
                        // Full-bleed blurred background
                        if let art = player.currentArtwork {
                            Image(uiImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.25), value: player.currentArtwork)
                        }
                        
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                LinearGradient(
                                    colors: [.black.opacity(0.65), .clear, .black.opacity(0.85)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .frame(width:geometry.size.width, height:geometry.size.height)
                    .ignoresSafeArea()
                    
                    VStack(alignment:.center) {
                        Spacer()
                        Group {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .frame(width: geometry.size.width.scaled(by: 0.8), height:geometry.size.height.scaled(by: 0.4), alignment: .init(horizontal: .center, vertical: .top))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                
                                if let art = player.currentArtwork {
                                    Image(uiImage: art)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width.scaled(by: 0.8), height:geometry.size.height.scaled(by: 0.4), alignment: .init(horizontal: .center, vertical: .top))
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                        .transition(.opacity.combined(with: .scale))
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.currentArtwork)
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 64, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: 0.25), value: player.currentArtwork)
                                }
                            }
                            .frame(width: geometry.size.width.scaled(by: 0.8), height:geometry.size.height.scaled(by: 0.4), alignment: .init(horizontal: .center, vertical: .top))

                        }
    
                        Spacer()
                        // Title / artist
                        VStack() {
                            Text(player.currentTitle.isEmpty ? "Unknown Title" : player.currentTitle)
                                .font(.title2.weight(.semibold))
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                            Text(player.currentArtist.isEmpty ? "Unknown Artist" : player.currentArtist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.bottom, 16)
                        .animation(.easeInOut(duration: 0.2), value: player.currentTitle)
                        .animation(.easeInOut(duration: 0.2), value: player.currentArtist)
                        Spacer()
                        
                        // Scrubber
                        VStack() {
                            Slider(
                                value: Binding(
                                    get: { player.scrubPosition },
                                    set: { newValue in
                                        player.scrubPosition = newValue
                                        // Only seek if we're actively scrubbing (not during programmatic updates)
                                        if player.isUserScrubbing {
                                            // Update currentTime immediately for visual feedback
                                            player.currentTime = newValue
                                        }
                                    }
                                ),
                                in: 0...max(player.duration, 0.1),
                                onEditingChanged: { editing in
                                    player.setIsScrubbing(editing)
                                }
                            )
                            .animation(.linear(duration: 0.1), value: player.scrubPosition)
                            
                            HStack {
                                Text(Self.format(player.currentTime))
                                Spacer()
                                Text(Self.format(player.duration))
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                        
                        // Transport
                        HStack() {
                            Button { player.skip(seconds: -15) } label: {
                                Image(systemName: "gobackward.15").font(.system(size: 28, weight: .semibold))
                                    .padding(.horizontal, 8)
                            }
                            
                            HStack() {
                                Button { player.previousTrackOrRestart() } label: {
                                    Image(systemName: "backward.end.fill").font(.system(size: 28, weight: .semibold))
                                        .padding(.horizontal, 4)

                                }
                                
                                Button { player.togglePlayPause() } label: {
                                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .scaleEffect(player.isPlaying ? 1.02 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: player.isPlaying)
                                        .font(.system(size: 72))
                                        .padding(.horizontal, 4)

                                }
                                
                                Button { player.nextTrack() } label: {
                                    Image(systemName: "forward.end.fill").font(.system(size: 28, weight: .semibold))
                                        .padding(.horizontal, 4)

                                }
                                .disabled(player.currentIndex >= player.effectivePlaylist.count - 1)
                            }
                            
                            Button { player.skip(seconds: +30) } label: {
                                Image(systemName: "goforward.30").font(.system(size: 28, weight: .semibold))
                                    .padding(.horizontal, 8)

                            }
                        }
                        .padding(.vertical, 16)
                        
                        // Volume Controls
                        HStack() {
                            // Volume Down Button
                            Button {
                                player.adjustVolume(-0.1)
                            } label: {
                                Image(systemName: "speaker.fill")
                                    .font(.title2)
                            }
                            
                            // Volume Slider
                            VolumeSlider()
                            
                            // Volume Up Button
                            Button {
                                player.adjustVolume(0.1)
                            } label: {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.title2)
                            }
                        }
                        .background(.clear)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .task {
                    let tourPOIs = currentPOIs.filter { $0.tour_id == selectedPOI.tour_id }
                    let startIndex = 0
                    player.replacePlaylist(tourPOIs, startAt: startIndex)
                    player.setTourTitleProvider { selectedTour?.title }
                    await MainActor.run {
                        player.activateSession()
                    }
                }
                .onDisappear { player.deactivateSession() }
                .onChange(of: selectedTour?.title ?? "") { _, newValue in
                    // Update the tour title provider when tour changes
                    withAnimation(.easeInOut) {
                        player.setTourTitleProvider { newValue }
                    }
                }
                .onChange(of: selectedPOI.id) { _, _ in
                    // When selectedPOI changes, update the playlist and start playing
                    withAnimation(.easeInOut) {
                        let tourPOIs = currentPOIs.filter { $0.tour_id == selectedPOI.tour_id }
                        let startIndex = tourPOIs.firstIndex(of: selectedPOI) ?? 0
                        player.replacePlaylist(tourPOIs, startAt: startIndex)
                        // Automatically start playing the new POI
                        if !player.isPlaying {
                            player.togglePlayPause()
                        }
                    }
                }
                .sheet(isPresented: $showingQueue) {
                    UpNextSheet(player: player)
                        .presentationDetents([.medium, .large])
                }
                .toolbar(content: {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.title2.weight(.semibold))
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // AirPlay Route Picker
                        AirPlayRoutePicker()
                            .frame(width: 44, height: 44, alignment: .center)
                        
                        Button {
                            showingQueue = true
                        } label: {
                            Label("Up Next", systemImage: "list.bullet")
                        }
                    }
                })
            }
        }
    }

    private static func format(_ t: Double) -> String {
        guard t.isFinite && t >= 0 else { return "00:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Up Next sheet

struct UpNextSheet: View {
    @ObservedObject var player: QueuePlayerEngine

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.effectivePlaylist.enumerated()), id: \.element.id) { idx, track in
                    HStack(spacing: 12) {
                        ArtworkThumb(poi:track)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                                .padding()
                        }
                        Spacer()
                        if idx == player.currentIndex {
                            Image(systemName: player.isPlaying ? "waveform.and.mic" : "pause")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.jump(toEffectiveIndex: idx)
                    }
                    .animation(.easeInOut(duration: 0.2), value: player.currentIndex)
                }
            }
            .navigationTitle("Up Next")
        }
    }
}

struct ArtworkThumb: View {
    let poi: POI
    @State private var artwork:UIImage?
    var body: some View {
        Group {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .frame(width: 60, height: 60)
            }
        }
        .task {
            if let url = try? await poi.downloadImage(), let (data, _) = try? await URLSession.shared.data(from: url), let
            image = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        artwork = image
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Queue Player Engine

final class QueuePlayerEngine: NSObject, ObservableObject {
    // Playback state
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0.0001
    @Published var scrubPosition: Double = 0

    // Metadata for current item
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentArtwork: UIImage?

    // Playlist
    @Published private(set) var playlist: [POI]
    @Published private(set) var effectivePlaylist: [POI] = []
    @Published private(set) var currentIndex: Int
    private var enqueuedItems: [AVPlayerItem] = []

    // External metadata providers
    private var tourTitleProvider: (() -> String?)?

    // Internals
    private let queue = AVQueuePlayer()
    private var timeObserver: Any?
    @Published var isUserScrubbing = false
    private var itemContext = 0
    
    // Track which item we're observing to prevent double removal
    private var observedItem: AVPlayerItem?

    // Artwork loading task to avoid races when switching tracks
    private var artworkTask: Task<Void, Never>?

    init(playlist: [POI], startAt: Int = 0) {
        self.playlist = playlist.sorted(by: {$0.order < $1.order})
        self.currentIndex = max(0, min(startAt, playlist.count - 1))
        super.init()
        configureQueue(startingAt: currentIndex)

        // Periodic time updates
        timeObserver = queue.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), // More frequent updates
            queue: .main
        ) { [weak self] t in
            guard let self else { return }
            let seconds = t.seconds
            guard seconds.isFinite && seconds >= 0 else { return }
            
            // Only update if we're not in the middle of a user interaction
            if !self.isUserScrubbing {
                self.currentTime = seconds
                self.scrubPosition = seconds
            } else {
                // Still update currentTime for consistency, but not scrubPosition
                self.currentTime = seconds
            }
        }

        // Item finished → advance
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime, object: nil
        )
    }
    
    deinit {
        // Clean up observers and time observer
        cleanupCurrentObserver()
        
        if let timeObserver = timeObserver {
            queue.removeTimeObserver(timeObserver)
        }
        
        NotificationCenter.default.removeObserver(self)
    }

    /// Replace the current playlist and rebuild the queue, optionally starting at a given index.
    func replacePlaylist(_ newPlaylist: [POI], startAt: Int = 0) {
        self.playlist = newPlaylist.sorted { $0.order < $1.order }
        self.currentIndex = max(0, min(startAt, max(newPlaylist.count - 1, 0)))
        configureQueue(startingAt: self.currentIndex)
    }
    
    /// Set the tour title provider for metadata display
    func setTourTitleProvider(_ provider: @escaping () -> String?) {
        self.tourTitleProvider = provider
        // Refresh metadata for current track if there is one
        if !effectivePlaylist.isEmpty && currentIndex < effectivePlaylist.count {
            refreshMetadataForCurrentTrack()
            updateNowPlayingInfo(fullRefresh: true, index:currentIndex)
        }
    }

    // Build / rebuild the queue from an index
    private func configureQueue(startingAt index: Int) {
        // Clean up any existing observers first
        cleanupCurrentObserver()
        queue.removeAllItems()

        guard !playlist.isEmpty else { return }

        let tail = Array(playlist[index...])
        let selectedPOI = playlist.indices.contains(index) ? playlist[index] : nil

        // Build items asynchronously keeping item<->POI pairing
        Task { [weak self] in
            guard let self else { return }
            let pairs = await self.loadPlayerItems(for: tail)

            await MainActor.run {
                // Sort by POI.order to ensure deterministic effective order
                let sortedPairs = pairs.sorted { $0.poi.order < $1.poi.order }

                // Determine the start position within the sorted tail
                let startIdx: Int = {
                    guard let selected = selectedPOI else { return 0 }
                    return sortedPairs.firstIndex(where: { $0.poi.id == selected.id }) ?? 0
                }()

                // Rotate so the selected item is first in the queue
                let rotatedPairs: [(item: AVPlayerItem, poi: POI)] = Array(sortedPairs[startIdx...] + sortedPairs[..<startIdx])

                // Rebuild enqueued items and effective playlist from rotated list
                self.queue.removeAllItems()
                self.enqueuedItems = rotatedPairs.map { $0.item }
                self.effectivePlaylist = rotatedPairs.map { $0.poi }

                var previous: AVPlayerItem? = nil
                for item in self.enqueuedItems {
                    self.queue.insert(item, after: previous)
                    previous = item
                }

                // Current item is now the selected one at index 0
                self.currentIndex = 0
                self.attachKVO(to: self.enqueuedItems.first)
                self.refreshMetadataForCurrentTrack()
                self.queue.actionAtItemEnd = .advance
                self.duration = self.queue.currentItem?.duration.seconds.isFinite == true ? self.queue.currentItem!.duration.seconds : 0
                self.currentTime = 0
                self.scrubPosition = 0
                self.updateNowPlayingInfo(fullRefresh: true, index: self.currentIndex)
            }
        }
    }

    private func loadPlayerItems(for pois: [POI]) async -> [(item: AVPlayerItem, poi: POI)] {
        await withTaskGroup(of: (AVPlayerItem, POI)?.self) { group in
            for poi in pois {
                group.addTask {
                    guard let audio_path = poi.audio_path else { return nil }
                    do {
                        let audioData = try await SupabaseService.shared.downloadAudio(at: audio_path)
                        return (AVPlayerItem(url: audioData), poi)
                    } catch {
                        return nil
                    }
                }
            }
            var collected: [(AVPlayerItem, POI)] = []
            for await result in group {
                if let pair = result {
                    collected.append(pair)
                }
            }
            return collected
        }
    }

    // MARK: Session

    func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error:", error)
        }
        setupRemoteCommands()
        if effectivePlaylist.count > 0 {
            updateNowPlayingInfo(fullRefresh: true, index:0)
        }
    }

    func deactivateSession() {
        // Clean up observers first
        cleanupCurrentObserver()
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let cmd = MPRemoteCommandCenter.shared()
        [cmd.playCommand, cmd.pauseCommand, cmd.togglePlayPauseCommand,
         cmd.nextTrackCommand, cmd.previousTrackCommand,
         cmd.changePlaybackPositionCommand, cmd.skipForwardCommand, cmd.skipBackwardCommand]
            .forEach { $0.isEnabled = false }
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: Controls

    func togglePlayPause() {
        if isPlaying { queue.pause() } else { queue.play() }
        isPlaying.toggle()
        updateNowPlayingPlaybackState()
    }

    func skip(seconds: Double) {
        let target = max(0, min(duration, currentTime + seconds))
        seek(to: target)
    }

    func setIsScrubbing(_ editing: Bool) {
        isUserScrubbing = editing
        if !editing {
            // When user finishes scrubbing, seek to the scrub position
            seek(to: scrubPosition)
        }
    }

    func seek(to seconds: Double) {
        let clampedSeconds = max(0, min(duration, seconds))
        let t = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
        
        // Update UI immediately for responsive feedback
        currentTime = clampedSeconds
        scrubPosition = clampedSeconds
        
        queue.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            guard let self = self, completed else { return }
            DispatchQueue.main.async {
                // Confirm the seek completed successfully
                self.currentTime = clampedSeconds
                self.scrubPosition = clampedSeconds
                self.updateNowPlayingInfo(fullRefresh: false, index: self.currentIndex)
            }
        }
    }

    func nextTrack() {
        guard currentIndex < effectivePlaylist.count - 1 else {
            // End of playlist
            queue.pause()
            isPlaying = false
            return
        }
        currentIndex += 1
        queue.advanceToNextItem()
        
        // Clean up observer from previous item and attach to new current item
        cleanupCurrentObserver()
        attachKVO(to: queue.currentItem)
        
        refreshMetadataForCurrentTrack()
        duration = queue.currentItem?.duration.seconds.isFinite == true ? queue.currentItem!.duration.seconds : 0
        currentTime = 0
        scrubPosition = 0
        if isPlaying { queue.play() }
        updateNowPlayingInfo(fullRefresh: true,index:currentIndex)
    }

    /// Apple Music behavior: if you tap previous within ~3 seconds of start, go to previous track, else restart.
    func previousTrackOrRestart() {
        if currentTime > 3 || currentIndex == 0 {
            // Restart current track
            seek(to: 0)
            return
        }
        // Go to previous track - rebuild queue starting at previous index
        currentIndex -= 1
        configureQueue(startingAt: currentIndex)
        if isPlaying { queue.play() }
    }

    func jump(toEffectiveIndex index: Int) {
        guard effectivePlaylist.indices.contains(index) else { return }
        let selected = effectivePlaylist[index]
        // Find this POI in the base playlist to respect tail building and rotation
        if let baseIndex = playlist.firstIndex(of: selected) {
            currentIndex = index
            configureQueue(startingAt: baseIndex)
            if isPlaying { queue.play() }
        }
    }

    func adjustVolume(_ delta: Float) {
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        let newVolume = max(0.0, min(1.0, currentVolume + delta))
        MPVolumeView.setVolume(newVolume)
    }

    @objc private func itemDidEnd(_ note: Notification) {
        // When an item ends, AVQueuePlayer auto-advances; keep our index in sync.
        if currentIndex < effectivePlaylist.count - 1 {
            currentIndex += 1
            refreshMetadataForCurrentTrack()
            duration = queue.currentItem?.duration.seconds.isFinite == true ? queue.currentItem!.duration.seconds : 0
            currentTime = 0
            scrubPosition = 0
            updateNowPlayingInfo(fullRefresh: true, index:currentIndex)
        } else {
            // End of playlist
            isPlaying = false
            updateNowPlayingPlaybackState()
            currentIndex = 0
        }
    }

    // MARK: Metadata & KVO

    private func attachKVO(to item: AVPlayerItem?) {
        // Only attach if we have an item and we're not already observing it
        guard let item = item, observedItem !== item else { return }
        
        // Clean up any existing observer first
        cleanupCurrentObserver()
        
        item.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: &itemContext)
        item.addObserver(self, forKeyPath: "duration", options: [.initial, .new], context: &itemContext)
        observedItem = item
    }

    private func removeKVO(from item: AVPlayerItem?) {
        guard let item = item, observedItem === item else { return }
        item.removeObserver(self, forKeyPath: "status", context: &itemContext)
        item.removeObserver(self, forKeyPath: "duration", context: &itemContext)
        observedItem = nil
    }
    
    private func cleanupCurrentObserver() {
        if let observedItem = observedItem {
            removeKVO(from: observedItem)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard context == &itemContext, let item = object as? AVPlayerItem else { return }
        switch keyPath {
        case "status":
            if item.status == .readyToPlay {
                duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                updateNowPlayingInfo(fullRefresh: true, index:currentIndex)
            }
        case "duration":
            duration = item.duration.seconds.isFinite ? item.duration.seconds : duration
            updateNowPlayingInfo(fullRefresh: false, index:currentIndex)
        default:
            break
        }
    }

    private func refreshMetadataForCurrentTrack() {
        guard !effectivePlaylist.isEmpty, effectivePlaylist.indices.contains(currentIndex) else {
            currentTitle = ""
            currentArtist = tourTitleProvider?() ?? ""
            currentArtwork = nil
            return
        }
        let track = effectivePlaylist[currentIndex]
        currentTitle = track.title
        currentArtist = tourTitleProvider?() ?? ""

        // Reset current artwork immediately for visual feedback
        currentArtwork = nil

        // Cancel any previous artwork loading task to prevent races
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                // Use the POI convenience method to get a signed image URL
                if let imageURL = try await track.downloadImage() {
                    // Fetch the image data asynchronously
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            // Only set if we're still on the same track
                            if self.effectivePlaylist.indices.contains(self.currentIndex), self.effectivePlaylist[self.currentIndex].id == track.id {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.currentArtwork = image
                                }
                                // Update Now Playing to include artwork
                                self.updateNowPlayingInfo(fullRefresh: true, index: self.currentIndex)
                            }
                        }
                    }
                }
            } catch {
                // Silently ignore artwork failures; leave artwork nil
            }
        }
    }

    // MARK: Now Playing / Remote commands

    private func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.isEnabled = true
        cmd.pauseCommand.isEnabled = true
        cmd.togglePlayPauseCommand.isEnabled = true
        cmd.nextTrackCommand.isEnabled = true
        cmd.previousTrackCommand.isEnabled = true
        cmd.changePlaybackPositionCommand.isEnabled = true
        cmd.skipForwardCommand.isEnabled = true
        cmd.skipBackwardCommand.isEnabled = true
        cmd.skipForwardCommand.preferredIntervals = [30]
        cmd.skipBackwardCommand.preferredIntervals = [15]

        cmd.playCommand.addTarget { [weak self] _ in self?.ensurePlaying(); return .success }
        cmd.pauseCommand.addTarget { [weak self] _ in self?.ensurePaused(); return .success }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cmd.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }
        cmd.previousTrackCommand.addTarget { [weak self] _ in self?.previousTrackOrRestart(); return .success }
        cmd.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime); return .success
        }
        cmd.skipForwardCommand.addTarget { [weak self] _ in self?.skip(seconds: 30); return .success }
        cmd.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(seconds: -15); return .success }
    }

    private func ensurePlaying() { if !isPlaying { togglePlayPause() } }
    private func ensurePaused() { if isPlaying { togglePlayPause() } }

    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingInfo(fullRefresh: Bool, index: Int? = nil) {
        guard let index = index else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if fullRefresh {
            info[MPMediaItemPropertyTitle] = currentTitle.isEmpty ? effectivePlaylist[index].title : currentTitle
            info[MPMediaItemPropertyArtist] = currentArtist.isEmpty ? (tourTitleProvider?() ?? "") : currentArtist
            if let img = currentArtwork {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            } else {
                info[MPMediaItemPropertyArtwork] = nil
            }
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - AirPlay & Volume bridges

struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = false
        return v
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    }
}

struct VolumeSlider: View {
    @State private var volume: Float = 0.5
    
    var body: some View {
        Slider(value: Binding(
            get: { Double(volume) },
            set: { newValue in
                volume = Float(newValue)
                // Set the system volume
                MPVolumeView.setVolume(volume)
            }
        ), in: 0...1)
        .background(Color.clear)
        .onAppear {
            // Get initial system volume
            volume = AVAudioSession.sharedInstance().outputVolume
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            // Update volume when system volume changes
            volume = AVAudioSession.sharedInstance().outputVolume
        }
    }
}

// Extension to help with setting system volume
extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
        }
    }
}

