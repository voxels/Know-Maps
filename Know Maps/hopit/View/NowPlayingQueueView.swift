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
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var player = QueuePlayerEngine(
        playlist: [],
        startAt: 0
    )

    @State private var showingQueue = false

    var body: some View {
        ZStack {
            // Full-bleed blurred background
            Group {
                if let art = player.currentArtwork {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 30, opaque: false)
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.65), .clear, .black.opacity(0.85)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                } else {
                    Rectangle().fill(.black)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen coverage

            VStack(spacing: 20) {
                HStack {
                    // Back button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // AirPlay Route Picker
                        AirPlayRoutePicker()
                            .frame(width: 44, height: 44)
                        
                        Button {
                            showingQueue = true
                        } label: {
                            Label("Up Next", systemImage: "list.bullet")
                                .labelStyle(.iconOnly)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding([.top, .horizontal])

                // Foreground artwork card
                if let art = player.currentArtwork {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(radius: 16)
                        .padding(.horizontal)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        Image(systemName: "music.note")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 320, height: 320)
                    .shadow(radius: 16)
                    .padding(.horizontal)
                }

                // Title / artist
                VStack(spacing: 4) {
                    Text(player.currentTitle.isEmpty ? "Unknown Title" : player.currentTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(player.currentArtist.isEmpty ? "Unknown Artist" : player.currentArtist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.top, 8)

                // Scrubber
                VStack(spacing: 10) {
                    Slider(value: $player.scrubPosition,
                           in: 0...max(player.duration, 0.1),
                           onEditingChanged: { editing in
                        player.setIsScrubbing(editing)
                    })
                    .tint(.white)

                    HStack {
                        Text(Self.format(player.currentTime))
                        Spacer()
                        Text(Self.format(player.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Transport
                HStack(spacing: 46) {
                    Button { player.skip(seconds: -15) } label: {
                        Image(systemName: "gobackward.15").font(.system(size: 28, weight: .semibold))
                    }

                    HStack(spacing: 34) {
                        Button { player.previousTrackOrRestart() } label: {
                            Image(systemName: "backward.end.fill").font(.system(size: 28, weight: .semibold))
                        }

                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 72))
                        }

                        Button { player.nextTrack() } label: {
                            Image(systemName: "forward.end.fill").font(.system(size: 28, weight: .semibold))
                        }
                    }

                    Button { player.skip(seconds: +30) } label: {
                        Image(systemName: "goforward.30").font(.system(size: 28, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.top, 6)

                // Volume Controls
                HStack(spacing: 12) {
                    // Volume Down Button
                    Button {
                        player.adjustVolume(-0.1)
                    } label: {
                        Image(systemName: "speaker.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    
                    // Volume Slider
                    VolumeSlider()
                        .frame(height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Volume Up Button  
                    Button {
                        player.adjustVolume(0.1)
                    } label: {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 40) // Increased spacing for full screen
            }
            .padding(.bottom, 40) // Increased bottom padding for full screen
            .padding(.top, 60) // Add top padding for full screen
        }
        .ignoresSafeArea(.all) // Add this for full screen
        .toolbar(.hidden, for: .tabBar) // Hide the tab bar
        .toolbar(.hidden, for: .navigationBar) // Hide the navigation bar for full immersion
        .interactiveDismissDisabled() // Prevent sheet dismissal gestures
        .onAppear {
            player.replacePlaylist([selectedPOI])
            player.setTourTitleProvider { selectedTour?.title }
            player.activateSession()
        }
        .onDisappear { player.deactivateSession() }
        .onChange(of: selectedTour?.title ?? "") { _ in
            // Update the tour title provider when tour changes
            player.setTourTitleProvider { selectedTour?.title }
        }
        .onChange(of: selectedPOI.id) { _ in
            // When selectedPOI changes, update the playlist and start playing
            player.replacePlaylist([selectedPOI], startAt: 0)
            // Automatically start playing the new POI
            if !player.isPlaying {
                player.togglePlayPause()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingQueue) {
            UpNextSheet(player: player)
                .presentationDetents([.medium, .large])
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
                ForEach(Array(player.playlist.enumerated()), id: \.element.id) { idx, track in
                    HStack(spacing: 12) {
//                        ArtworkThumb(image:)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        }
                        Spacer()
                        if idx == player.currentIndex {
                            Image(systemName: player.isPlaying ? "waveform.and.mic" : "pause")
                                .foregroundStyle(.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.jump(to: idx)
                    }
                }
            }
            .navigationTitle("Up Next")
        }
    }
}

struct ArtworkThumb: View {
    let image: URL?
    var body: some View {
        Group {
            if let image {
                LazyImage(url: image)
            } else {
                ZStack { Rectangle().fill(.quaternary); Image(systemName: "music.note") }
            }
        }
        .frame(width: 44, height: 44)
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
    @Published private(set) var currentIndex: Int

    // External metadata providers
    private var tourTitleProvider: (() -> String?)?

    // Internals
    private let queue = AVQueuePlayer()
    private var timeObserver: Any?
    private var isUserScrubbing = false
    private var itemContext = 0

    init(playlist: [POI], startAt: Int = 0) {
        self.playlist = playlist
        self.currentIndex = max(0, min(startAt, playlist.count - 1))
        super.init()
        configureQueue(startingAt: currentIndex)

        // Periodic time updates
        timeObserver = queue.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            guard let self else { return }
            let seconds = t.seconds
            self.currentTime = seconds
            if !self.isUserScrubbing {
                self.scrubPosition = seconds
            }
        }

        // Item finished → advance
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime, object: nil
        )
    }

    /// Replace the current playlist and rebuild the queue, optionally starting at a given index.
    func replacePlaylist(_ newPlaylist: [POI], startAt: Int = 0) {
        self.playlist = newPlaylist
        self.currentIndex = max(0, min(startAt, max(newPlaylist.count - 1, 0)))
        configureQueue(startingAt: self.currentIndex)
    }
    
    /// Set the tour title provider for metadata display
    func setTourTitleProvider(_ provider: @escaping () -> String?) {
        self.tourTitleProvider = provider
        // Refresh metadata for current track if there is one
        if !playlist.isEmpty && currentIndex < playlist.count {
            refreshMetadataForCurrentTrack()
            updateNowPlayingInfo(fullRefresh: true)
        }
    }

    // Build / rebuild the queue from an index
    private func configureQueue(startingAt index: Int) {
        queue.removeAllItems()
        removeKVO(from: queue.currentItem)

        guard !playlist.isEmpty else { return }

        let tail = Array(playlist[index...])

        // Build items asynchronously using a task group
        Task { [weak self] in
            guard let self else { return }
            let items = await self.loadPlayerItems(for: tail)

            await MainActor.run {
                var previous: AVPlayerItem? = nil
                for item in items {
                    self.queue.insert(item, after: previous)
                    previous = item
                }

                self.attachKVO(to: items.first)
                self.refreshMetadataForCurrentTrack()
                self.queue.actionAtItemEnd = .advance
                self.duration = self.queue.currentItem?.duration.seconds.isFinite == true ? self.queue.currentItem!.duration.seconds : 0
                self.currentTime = 0
                self.scrubPosition = 0
                self.updateNowPlayingInfo(fullRefresh: true)
            }
        }
    }

    private func loadPlayerItems(for pois: [POI]) async -> [AVPlayerItem] {
        await withTaskGroup(of: AVPlayerItem?.self) { group in
            for poi in pois {
                group.addTask {
                    guard let audio_path = poi.audio_path else { return nil }
                    do {
                        let audioData = try await SupabaseService.shared.downloadAudio(at: audio_path)
                        return AVPlayerItem(url: audioData)
                    } catch {
                        // Failed to download or write; skip this item
                        return nil
                    }
                }
            }

            var collected: [AVPlayerItem] = []
            for await result in group {
                if let item = result {
                    collected.append(item)
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
        updateNowPlayingInfo(fullRefresh: true)
    }

    func deactivateSession() {
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
        if !editing { seek(to: scrubPosition) }
    }

    private func seek(to seconds: Double) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        queue.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.currentTime = seconds
            self?.updateNowPlayingInfo(fullRefresh: false)
        }
    }

    func nextTrack() {
        guard currentIndex < playlist.count - 1 else {
            // End of playlist
            queue.pause()
            isPlaying = false
            return
        }
        currentIndex += 1
        queue.advanceToNextItem()
        removeKVO(from: queue.currentItem)
        attachKVO(to: queue.currentItem)
        refreshMetadataForCurrentTrack()
        duration = queue.currentItem?.duration.seconds.isFinite == true ? queue.currentItem!.duration.seconds : 0
        currentTime = 0
        scrubPosition = 0
        if isPlaying { queue.play() }
        updateNowPlayingInfo(fullRefresh: true)
    }

    /// Apple Music behavior: if you tap previous within ~3 seconds of start, go to previous track, else restart.
    func previousTrackOrRestart() {
        if currentTime > 3 || currentIndex == 0 {
            seek(to: 0)
            return
        }
        // Rebuild queue starting at previous index
        currentIndex -= 1
        configureQueue(startingAt: currentIndex)
        if isPlaying { queue.play() }
    }

    func jump(to index: Int) {
        guard playlist.indices.contains(index) else { return }
        currentIndex = index
        configureQueue(startingAt: index)
        if isPlaying { queue.play() }
    }

    func adjustVolume(_ delta: Float) {
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        let newVolume = max(0.0, min(1.0, currentVolume + delta))
        MPVolumeView.setVolume(newVolume)
    }

    @objc private func itemDidEnd(_ note: Notification) {
        // When an item ends, AVQueuePlayer auto-advances; keep our index in sync.
        if currentIndex < playlist.count - 1 {
            currentIndex += 1
            refreshMetadataForCurrentTrack()
            duration = queue.currentItem?.duration.seconds.isFinite == true ? queue.currentItem!.duration.seconds : 0
            currentTime = 0
            scrubPosition = 0
            updateNowPlayingInfo(fullRefresh: true)
        } else {
            // End of playlist
            isPlaying = false
            updateNowPlayingPlaybackState()
        }
    }

    // MARK: Metadata & KVO

    private func attachKVO(to item: AVPlayerItem?) {
        item?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: &itemContext)
        item?.addObserver(self, forKeyPath: "duration", options: [.initial, .new], context: &itemContext)
    }

    private func removeKVO(from item: AVPlayerItem?) {
        guard let item else { return }
        item.removeObserver(self, forKeyPath: "status", context: &itemContext)
        item.removeObserver(self, forKeyPath: "duration", context: &itemContext)
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
                updateNowPlayingInfo(fullRefresh: true)
            }
        case "duration":
            duration = item.duration.seconds.isFinite ? item.duration.seconds : duration
            updateNowPlayingInfo(fullRefresh: false)
        default:
            break
        }
    }

    private func refreshMetadataForCurrentTrack() {
        let track = playlist[currentIndex]
        currentTitle = track.title
        currentArtwork = nil
        currentArtist = tourTitleProvider?() ?? ""

        // Try embedded metadata/artwork if any
        if let item = queue.currentItem {
            for meta in item.asset.commonMetadata {
                guard let key = meta.commonKey?.rawValue else { continue }
                if key == "title", let s = meta.stringValue { currentTitle = s }
                if key == "artist", let s = meta.stringValue { currentArtist = s }
                if key == "artwork", let data = meta.dataValue, let img = UIImage(data: data) {
                    currentArtwork = img
                }
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

    private func updateNowPlayingInfo(fullRefresh: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if fullRefresh {
            info[MPMediaItemPropertyTitle] = currentTitle.isEmpty ? playlist[currentIndex].title : currentTitle
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
        v.tintColor = UIColor.white
        v.activeTintColor = UIColor.white
        return v
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor.white
        uiView.activeTintColor = UIColor.white
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
        .tint(.white)
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
