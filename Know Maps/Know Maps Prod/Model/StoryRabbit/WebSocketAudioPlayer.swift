import AVFoundation
import MediaPlayer

class WebSocketAudioPlayer: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode = AVAudioPlayerNode()
    private var audioFormat: AVAudioFormat?
    private var audioBufferQueue: [AVAudioPCMBuffer] = []
    private var isBuffering = false
    private var shouldNotifyFinal = false // Tracks if we should notify `isFinal`
    
    var playerState: PlayerState = .loading
    var pendingRabbitholeInfo = true;
    var currentTitle = "";
    var currentRabbitholeTitle = "";
    var currentHostAvatarUrl = "";
    var transcript = "";
    var currentlevel = 0;
    var currentPodcastId = 0;
    var currentRabbitholeId = 0;
    var currentFollowUps: [FollowUpQuestion] = []
    
    private var isResuming = false
    private var pauseTimestamp: TimeInterval?
    private var currentPlaybackTime: TimeInterval = 0
    private var playbackStartTime: TimeInterval = 0
    private var backgroundPlayer: AVAudioPlayer?
    private var triggerPlayer: AVAudioPlayer?
    private var isWebSocketPlaying = false // Flag to check if WebSocket has started playing
    private var isStopped = false

    
    func stop() {
        print("Stopping playback and resetting player.")
        
        // Set stopped flag
        isStopped = true
        
        // Stop the player node and clear buffers
        playerNode.stop()
        playerNode.reset()
        audioBufferQueue.removeAll()
        
        // Reset playback state and metadata
        isBuffering = false
        shouldNotifyFinal = false
        playerState = .loading
        currentTitle = ""
        transcript = ""
        currentPodcastId = 0
        currentFollowUps.removeAll()
        
        // Stop and reset the audio engine
        audioEngine.stop()
        audioEngine.reset()
        
        // Restart the audio engine to prepare for future playback
        do {
            try audioEngine.start()
            print("Audio engine reset and restarted.")
        } catch {
            print("Error restarting audio engine: \(error.localizedDescription)")
        }
        
        // Optionally close the WebSocket
        self.closeWebSocket(closeCode: 3001, reason: "cancel")
        endAudioSession()
        hideLockscreenMediaPlayer()
    }

    func play() {
        guard playerState == .paused else {
            print("Playback is already running.")
            return
        }
        
        print("Resuming playback.")
        isStopped = false
        playerState = .playing

        if let pauseTime = pauseTimestamp {
            let elapsedPauseTime = Date().timeIntervalSince1970 - pauseTime
            currentPlaybackTime += elapsedPauseTime
            pauseTimestamp = nil
        }

        playbackStartTime = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        playAudioBuffer()
        
        // Update Now Playing Info
        showLockscreenMediaPlayer()
    }

    func pause() {
        guard playerState != .paused else {
            print("Playback is already paused.")
            return
        }
        
        print("Pausing playback.")
        playerState = .paused
        pauseTimestamp = Date().timeIntervalSince1970
        playerNode.stop()
        
        // Update Now Playing Info
        //showLockscreenMediaPlayer()
    }


    private func playBackgroundLoop() {
        guard let url = Bundle.main.url(forResource: "generating_loop_0", withExtension: "wav") else {
            print("Failed to load background loop file.")
            return
        }

        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1 // Infinite loop
            backgroundPlayer?.play()
        } catch {
            print("Error initializing background player: \(error.localizedDescription)")
        }
    }
    
    private func playTriggerSound() {
        guard let url = Bundle.main.url(forResource: "PLAY", withExtension: "wav") else {
            print("Failed to load trigger sound file.")
            return
        }

        do {
            triggerPlayer = try AVAudioPlayer(contentsOf: url)
            triggerPlayer?.play()
        } catch {
            print("Error initializing trigger player: \(error.localizedDescription)")
        }
    }
    
    func hideLockscreenMediaPlayer(){
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.playCommand.isEnabled = false
            commandCenter.pauseCommand.isEnabled = false
            commandCenter.stopCommand.isEnabled = false
            commandCenter.nextTrackCommand.isEnabled = false
            commandCenter.previousTrackCommand.isEnabled = false
        
        
        let commandCenter2 = MPRemoteCommandCenter.shared()
        commandCenter2.playCommand.removeTarget(nil)
        commandCenter2.pauseCommand.removeTarget(nil)
    }
    
    func showLockscreenMediaPlayer() {
        // Configure remote commands
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPMediaItemPropertyAlbumTitle: "Rabbithole",
            MPNowPlayingInfoPropertyPlaybackRate: playerState == .playing ? 1.0 : 0.0
        ]
        
        // URL of the album art
        if let albumArtURL = URL(string: currentHostAvatarUrl) {
            let session = URLSession.shared
            let task = session.dataTask(with: albumArtURL) { data, response, error in
                if let error = error {
                    print("Failed to fetch album art: \(error)")
                    return
                }
                
                if let data = data, let albumArtImage = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: albumArtImage.size) { _ in
                        return albumArtImage
                    }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                }
                
                // Update the now playing info on the main thread
                DispatchQueue.main.async {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
            task.resume()
        } else {
            // Update now playing info without artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    func getProgress() -> [String: Any?] {
        return [
            "playerTime":0,
            "currentChapter": dictionaryToJsonString(convertToDictionary(Podcast(id: self.currentPodcastId, title: self.currentTitle, transcript: self.transcript, followUps: self.currentFollowUps))!),
            "currentRabbithole": dictionaryToJsonString(convertToDictionary(Podcast(id: self.currentRabbitholeId, title: self.currentRabbitholeTitle, transcript: self.transcript, followUps: self.currentFollowUps))!),
            "currentLevel":  self.currentlevel,
            "playerState": self.playerState.rawValue
        ];
    }
    
    func dictionaryToJsonString(_ dictionary: [String: Any]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error converting dictionary to JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertToDictionary<T: Codable>(_ object: T) -> [String: Any]? {
        do {
            // Encode the object into Data
            let jsonData = try JSONEncoder().encode(object)
            
            // Decode the Data back into a Dictionary
            if let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any] {
                return dictionary
            }
        } catch {
            print("Error converting object to dictionary: \(error.localizedDescription)")
        }
        return nil
    }
    func applyFade(to buffer: AVAudioPCMBuffer, duration: Double = 0.01) {
        let fadeFrameCount = Int(duration * buffer.format.sampleRate)
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        
        // Fade in
        for i in 0..<min(fadeFrameCount, frameLength) {
            channelData?[i] *= Float(i) / Float(fadeFrameCount)
        }

        // Fade out
        for i in max(0, frameLength - fadeFrameCount)..<frameLength {
            channelData?[i] *= Float(frameLength - i) / Float(fadeFrameCount)
        }
    }
    private func loadTriggerSound() -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: "PLAY_fixed", withExtension: "wav") else {
            print("Failed to load trigger sound file.")
            return nil
        }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("Failed to create PCM buffer for trigger sound.")
                return nil
            }
            
            try audioFile.read(into: buffer)
            return buffer
        } catch {
            print("Error loading trigger sound: \(error.localizedDescription)")
            return nil
        }
    }

  
    private func playAudioBuffer() {
        guard playerState != .paused else {
            print("Playback is paused, skipping buffer playback.")
            return
        }

        if audioBufferQueue.isEmpty {
            isBuffering = false

            // Notify the final buffer completion if applicable
            if shouldNotifyFinal {
                DispatchQueue.main.async {
                    print("Final audio buffer finished.")
                    self.playerState = PlayerState.finished
                }
                shouldNotifyFinal = false
            }
            return
        }

        // Inject trigger sound if this is the first playback
        if !isWebSocketPlaying {
            isWebSocketPlaying = true
            backgroundPlayer?.stop()

            if let triggerBuffer = loadTriggerSound() {
                print("Injecting trigger sound into the buffer queue.")
                audioBufferQueue.insert(triggerBuffer, at: 0)
            }
        }

        startWebSocketAudio()
    }

    private func startWebSocketAudio() {
        guard !audioBufferQueue.isEmpty else {
            print("No audio buffers to play.")
            return
        }

        isBuffering = true
        let buffer = audioBufferQueue.removeFirst()

        // Apply fade to the buffer
        applyFade(to: buffer)

        // Schedule the buffer for playback
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: { [weak self] in
            self?.playAudioBuffer()
        })

        if !playerNode.isPlaying {
            playerNode.play()
            playerState = .playing
        }
    }

    
    func endAudioSession() {
        // Stop the audio engine and detach nodes
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.detach(playerNode)

        // Deactivate AVAudioSession
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }

        print("Audio engine and AVAudioSession deinitialized.")
        hideLockscreenMediaPlayer()
    }
    
    override init() { super.init()
        self.setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioEngine.attach(playerNode)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
        
        // Configure AVAudioSession
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        
        
    }

    
    private func processAudioData(_ audioData: Data) {
      
        guard !isStopped else {
            print("Received audio chunk while stopped. Ignoring.")
            return
        }

        if playerState == .paused {
            print("Buffer received while paused. Discarding.")
            return // Discard buffers while paused
        }

        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: audioData, options: []) as? [String: Any],
               let audioValue = jsonObject["audio"] {
                if audioValue is NSNull {
                    print("Final audio chunk detected. Adding silent buffer.")

                    // Add silent buffer directly
                    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    if let silentBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 44100) {
                        silentBuffer.frameLength = 44100
                        memset(silentBuffer.floatChannelData![0], 0, Int(silentBuffer.frameLength) * MemoryLayout<Float>.size)

                        audioBufferQueue.append(silentBuffer)
                        shouldNotifyFinal = true
                        if !isBuffering { playAudioBuffer() }
                    }
                } else if let base64String = audioValue as? String,
                          let decodedData = Data(base64Encoded: base64String) {
                    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    let frameCount = max(AVAudioFrameCount(decodedData.count / MemoryLayout<Int16>.size), 1024) // Ensure a minimum size
                    if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) {
                        buffer.frameLength = frameCount
                        decodedData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                            let int16Pointer = rawBuffer.bindMemory(to: Int16.self).baseAddress!
                            let floatPointer = buffer.floatChannelData![0]

                            for i in 0..<Int(frameCount) {
                                floatPointer[i] = Float(int16Pointer[i]) / 32768.0
                            }
                        }

                        audioBufferQueue.append(buffer)
                        if !isBuffering { playAudioBuffer() }
                    }

                }
            }
        } catch {
            print("Error processing audio data: \(error.localizedDescription)")
        }
    }
    
    private func receiveMessages() {
        guard let webSocketTask = webSocketTask, !isStopped else {
            print("WebSocket receiving stopped or task is nil.")
            return
        }
        
        webSocketTask.receive { [weak self] result in
            guard let self = self, !self.isStopped else {
                print("Ignoring message as playback is stopped.")
                return
            }
            
            
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            case .success(let message):
                switch message {
                    
                case .string(let text):
                    print("Received \(text.count.description)")
                    
                    // Attempt to parse the text as JSON
                    if let jsonData = text.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
                       let jsonDict = jsonObject as? [String: Any] {
                        
                        // Check for "type" field
                        if let type = jsonDict["type"] as? String, type == "AUDIO" {
                            if let payload = jsonDict["payload"] as? [String: Any],
                               let audioChunk = payload["audioChunk"] as? [String: Any],
                               let dataArray = audioChunk["data"] as? [UInt8] {
                                
                                // Convert [UInt8] to Data
                                let audioData = Data(dataArray)
                                self.processAudioData(audioData)
                                
                            } else {
                                print("Invalid AUDIO payload structure: \(text)")
                            }
                        } else if let type = jsonDict["type"] as? String, type == "INFO" {
                            if let payload = jsonDict["payload"] as? [String: Any],
                               let title = payload["title"] as? String,
                               let level = payload["level"] as? Int,
                            let personaJsonDict = payload["persona"] as? [String: Any],
                            let personaPictureUrl = personaJsonDict["pictureUrl"] as? String{
                                
                                // Handle INFO message
                                print("INFO message received: title=\(title), level=\(level), pictureUrl=\(personaPictureUrl)")
                                
                                // Podcast info
                                self.currentTitle = title;
                                self.currentlevel = level;
                                self.currentHostAvatarUrl = personaPictureUrl;
                                
                                // Rabbithole info
                                if(self.pendingRabbitholeInfo == true){
                                    self.currentlevel == 0;
                                    self.currentRabbitholeTitle = title;
                                    
                                }
                                showLockscreenMediaPlayer()
                                
                            } else if let payload = jsonDict["payload"] as? [String: Any],
                                      let podcastId = payload["podcastId"] as? Int,
                                      let followUpsArray = payload["followUps"] as? [[String: Any]] {
                                
                                // Parse followUps
                                var followUps: [FollowUpQuestion] = []
                                for followUpDict in followUpsArray {
                                    if let id = followUpDict["id"] as? Int,
                                       let content = followUpDict["content"] as? String {
                                        followUps.append(FollowUpQuestion(id: id, content: content))
                                    }
                                }
                                
                                // Handle INFO message
                                print("INFO message received: podcastId=\(podcastId), followUps=\(followUps)")
                                
                                self.currentFollowUps = followUps
                                self.currentPodcastId = podcastId
                                // Rabbithole info
                                if(self.pendingRabbitholeInfo == true){
                                    self.currentRabbitholeId = podcastId
                                    self.pendingRabbitholeInfo = false;
                                }
                                // At this point we can close the socket
                                self.closeWebSocket(closeCode: URLSessionWebSocketTask.CloseCode.normalClosure.rawValue, reason: nil);
                                
                            } else {
                                print("Invalid INFO payload structure: " + text)
                            }
                        }
                        else if let type = jsonDict["type"] as? String, type == "TRANSCRIPT" {
                            if let payload = jsonDict["payload"] as? [String: Any],
                               let textChunk = payload["textChunk"] as? String {
                                
                                // Handle TRANSCRIPT message
                                print("TRANSCRIPT message received: textChunk=\(textChunk),")
                                self.transcript += textChunk;
                            }
                        } else {
                            print("Unknown message type: \(String(describing: jsonDict["type"]))")
                        }
                    } else {
                        print("Unable to parse JSON message.")
                    }
                    
                @unknown default:
                    print("Unknown WebSocket message received")
                }
            }
            self.receiveMessages()
        }
    }
    
    func closeWebSocket(closeCode: Int, reason: String?) {
        guard let webSocketTask = webSocketTask else {
            print("WebSocket task is nil.")
            return
        }
        
        let code = UInt16(closeCode)
        let reasonData = reason?.data(using: .utf8)
         backgroundPlayer?.stop()
        webSocketTask.cancel(with: URLSessionWebSocketTask.CloseCode(rawValue: Int(code)) ?? URLSessionWebSocketTask.CloseCode.invalid, reason: reasonData)
        self.webSocketTask = nil
        print("WebSocket closed with custom code \(closeCode) and reason: \(reason ?? "No reason provided"). WebSocket task set to nil.")
    }
    
    func generateStory(payload: [String: Any], event: String, token: String, websocketURL:String) {
        setupAudioSession()
        // Connect to websocket
        guard let url = URL(string: websocketURL) else {
//            result(FlutterError(code: "INVALID_URL", message: "Invalid WebSocket URL", details: nil))
            return
        }
        self.isWebSocketPlaying = false
        self.playBackgroundLoop()
        self.isStopped = false
        

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.maximumMessageSize = 10 * 1024 * 1024;
        webSocketTask?.resume()
        receiveMessages()
        guard let webSocketTask = webSocketTask else {
//            result(FlutterError(code: "WEBSOCKET_TASK_ERROR", message: "WebSocket task is nil", details: nil))
            return
        }
        
        // Set rabbithole level
        if(event == "generate-rabbithole-followup"){
            self.currentlevel == self.currentlevel + 1;
            self.pendingRabbitholeInfo = false;
        } else {
            self.currentRabbitholeId = 0;
            self.currentlevel = 0
            self.pendingRabbitholeInfo = true;
        }
        
        // Requsts story via websocket
        if webSocketTask.state == .running {
            let message: [String: Any] = ["event": event, "data": payload]
            do {
                let data = try JSONSerialization.data(withJSONObject: message, options: [])
                let text = String(data: data, encoding: .utf8) ?? ""
                webSocketTask.send(.string(text)) { error in
                    if let error = error {
                        print("failed to send message")
//                        result(FlutterError(code: "SEND_ERROR", message: "Failed to send message", details: error.localizedDescription))
                    } else {
                        print("message sent:  \(event)")
                    }
                }
            } catch {
//                result(FlutterError(code: "ENCODING_ERROR", message: "Failed to encode message as JSON", details: error.localizedDescription))
                return
            }
        }
//        else {
//            result(FlutterError(code: "WEBSOCKET_NOT_OPEN", message: "WebSocket is not open", details: "ReadyState: \(webSocketTask.state.rawValue)"))
//        }
    }
    
}

