//
//  Untitled.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/22/25.
//

import Foundation
import BackgroundTasks
import AVKit
import MediaPlayer

enum StoryRabbitMethod : String {
    case cancelGenerating
    case pause
    case stop
    case next
    case playRabbithole
    case killTask
    case requestUpdate
    case generateFollowUp
    case createFromSingle
    case createFromMulti
    case playSpashScreenSound
}


enum PlayerState : String {
    case loading = "loading"
    case playing = "playing"
    case paused = "paused"
    case finished = "finished"
}

enum OutputFormat : String {
    case mp3_44100 = "mp3_44100"
    case pcm_16000 = "pcm_16000"
    case pcm_22050 = "pcm_22050"
    case pcm_24000 = "pcm_24000"
    case pcm_44100 = "pcm_44100"
}

@Observable
public final class StoryRabbitController  {

    static var STREAMING_ENABLED = true;

    var audioPlayer: AVQueuePlayer?
    var effectsPlayer: AVAudioPlayer?
    var generatingAudioURL0: URL?
    var generatingAudioURL1: URL?
    var generatingAudioURL2: URL?
    var generatingAudioURL3: URL?
    var generatingAudioURL4: URL?
    var playerState: PlayerState = .loading
    var chapter: Podcast?
    var rabbithole: Podcast?
    var level: Int?
    var lastCompletedLevel: Int?
    var isNewRabbitHole: Bool?
    var remoteAudioURL: URL?
    var playerItem: AVPlayerItem?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var progressTimer: Timer?
    var boundaryTimeObserver: Any?
    var remotePlayed: Bool?
    var streamAudioPlayer: WebSocketAudioPlayer?
    
    var playerProgress:[String:Any?]? = nil
    
    init(
        audioPlayer: AVQueuePlayer? = nil, effectsPlayer: AVAudioPlayer? = nil, generatingAudioURL0: URL? = nil, generatingAudioURL1: URL? = nil, generatingAudioURL2: URL? = nil, generatingAudioURL3: URL? = nil, generatingAudioURL4: URL? = nil, playerState: PlayerState, chapter: Podcast? = nil, rabbithole: Podcast? = nil, level: Int? = nil, lastCompletedLevel: Int? = nil, isNewRabbitHole: Bool? = nil, remoteAudioURL: URL? = nil, playerItem: AVPlayerItem? = nil, backgroundTask: UIBackgroundTaskIdentifier, progressTimer: Timer? = nil, boundaryTimeObserver: Any? = nil, remotePlayed: Bool? = nil, streamAudioPlayer: WebSocketAudioPlayer? = nil) {
        self.audioPlayer = audioPlayer
        self.effectsPlayer = effectsPlayer
        self.generatingAudioURL0 = generatingAudioURL0
        self.generatingAudioURL1 = generatingAudioURL1
        self.generatingAudioURL2 = generatingAudioURL2
        self.generatingAudioURL3 = generatingAudioURL3
        self.generatingAudioURL4 = generatingAudioURL4
        self.playerState = playerState
        self.chapter = chapter
        self.rabbithole = rabbithole
        self.level = level
        self.lastCompletedLevel = lastCompletedLevel
        self.isNewRabbitHole = isNewRabbitHole
        self.remoteAudioURL = remoteAudioURL
        self.playerItem = playerItem
        self.backgroundTask = backgroundTask
        self.progressTimer = progressTimer
        self.boundaryTimeObserver = boundaryTimeObserver
        self.remotePlayed = remotePlayed
        self.streamAudioPlayer = streamAudioPlayer
        buildModel()
    }
    
    func buildModel() {
        // Init audio player
//        self.streamAudioPlayer = WebSocketAudioPlayer()
        
        self.generatingAudioURL0 = Bundle.main.url(forResource: "generating_loop_0", withExtension: "wav")!
        self.generatingAudioURL1 = Bundle.main.url(forResource: "generating_loop_1", withExtension: "wav")!
        self.generatingAudioURL2 = Bundle.main.url(forResource: "generating_loop_2", withExtension: "wav")!
        self.generatingAudioURL3 = Bundle.main.url(forResource: "generating_loop_3", withExtension: "wav")!
        self.generatingAudioURL4 = Bundle.main.url(forResource: "generating_loop_4", withExtension: "wav")!
        self.playerItem = AVPlayerItem(url: self.generatingAudioURL0!)
        self.audioPlayer = AVQueuePlayer(items: [self.playerItem!])
        self.addBoundaryTimeObserver()
        self.registerBackgroundTask()
    }
    
    
    func call(method:StoryRabbitMethod) {
        // Cancel generating
        if method.rawValue == "cancelGenerating"{
            if(StoryRabbitController.STREAMING_ENABLED){
                
                self.streamAudioPlayer!.closeWebSocket(closeCode: 3001, reason: "cancel")
            } else {
                self.playerState = .finished
                self.playerProgress = self.sendPlayerProgress()
                self.audioPlayer?.pause()
                self.audioPlayer?.seek(to: CMTime.zero)
            }
        }
        
        // Pause
        if method.rawValue == "pause" {
            self.playerState = .paused
            self.audioPlayer?.pause()
            if(StoryRabbitController.STREAMING_ENABLED) {self.streamAudioPlayer!.pause()}
        }
        
        // Stop
        if method.rawValue == "stop" {
            self.stop()
        }
        
        // Resume
        if method.rawValue == "continue" {
            if(self.isNewRabbitHole == false || !StoryRabbitController.STREAMING_ENABLED){
                self.playerState = .playing
                self.audioPlayer?.play()
                return;
            }
            self.streamAudioPlayer!.play()
        }
        
        // Play rabbit hole
        if method.rawValue == "playRabbithole" {
            self.configureAudioSession()
            
            let args:[String:Any] = [:]

            // Ensure the arguments are of the correct type
            guard let baseUrl = args["baseUrl"] as? String,
                  let token = args["token"] as? String else {
                return
            }
                        
            print(token)
            let shareId = args["shareId"] as? String;
            let id = args["id"] as? Int;
            let startFromChildAt = args["startFromChildAt"] as? Int;
            
            self.isNewRabbitHole = false
            self.playRabbithole(baseUrl: baseUrl,
                                shareId : shareId,
                                id : id,
                                startFromChildAt : startFromChildAt,
                                token : token)
        }
        
        // Kill task
        else if method.rawValue == "killTask" {
            self.streamAudioPlayer!.closeWebSocket(closeCode: 3001, reason: "cancel")
            self.endBackgroundTask();
        }
        
        // Request UI update
        else if (method.rawValue == "requestUpdateUI") {
            playerProgress = self.sendPlayerProgress()
        }
        // generate story
        else if (method.rawValue == "generateFollowup" || method.rawValue == "createFromSingle" || method.rawValue == "createFromMulti") {
            
            // OLD NON-STREAMING IMPLEMENTATION
            if(!StoryRabbitController.STREAMING_ENABLED){
                self.configureAudioSession()
                if (method.rawValue == "generateFollowup") {
                    // Ensure the arguments are of the correct type
                    
                    let args:[String:Any] = [:]
                    
                    // Extract and validate
                    guard let baseUrl = args["baseUrl"] as? String,
                          let parentId = args["parentId"] as? Int,
                          let followUpId = args["followUpId"] as? Int,
                          let token = args["token"] as? String else {
                        return
                    }
                    self.createFollowUp(baseUrl:baseUrl + "podcast/"+parentId.description+"/followUp/"+followUpId.description, token:token )
                }else if(method.rawValue == "createFromSingle"){
                    
                    let args:[String:Any] = [:]

                    // Extract and validate hostId, baseUrl, and token
                    guard let baseUrl = args["baseUrl"] as? String,
                          let payload = args["payload"] as? String,
                          let token = args["token"] as? String else {
                        
                        return
                    }
                    self.isNewRabbitHole = true
                    self.createRabbithole(payload:payload, baseUrl:baseUrl + "podcast/poi-single", token:token )
                }
                else if(method.rawValue == "createFromMulti"){
                    let args:[String:Any] = [:]

                    // Extract and validate hostId, baseUrl, and token
                    guard let baseUrl = args["baseUrl"] as? String,
                          let payload = args["payload"] as? String,
                          let token = args["token"] as? String else {
                        return
                    }
                    self.isNewRabbitHole = true
                    self.createRabbithole(payload:payload, baseUrl:baseUrl + "podcast/poi-multi", token:token)
                }
                
                return;
            }
            
            self.stop();
            
            // Pick event name
            var eventName = "generate-rabbithole-followup";
            if(method.rawValue == "createFromSingle") {eventName = "generate-rabbithole-poi-single";}
            else if(method.rawValue == "createFromMulti") {eventName = "generate-rabbithole-poi-multi";}
            
            let args:[String:Any] = [:]

            // Ensure the arguments are of the correct type
            
            // Extract and validate hostId, baseUrl, and token
            guard let baseUrl = args["baseUrl"] as? String,
                  let payload = args["payload"] as? String,
                  let token = args["token"] as? String else {
                return
            }
            if let payloadData = payload.data(using: .utf8) {
                do {
                    if let jsonDictionary = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] {
                        
                        self.playerState = .loading
                        playerProgress = self.sendPlayerProgress()
                        self.isNewRabbitHole = true
                        self.streamAudioPlayer!.generateStory(payload: jsonDictionary, event: eventName, token: token, websocketURL:baseUrl)
                    } else {
                        print("The JSON is not a dictionary.")
                    }
                } catch {
                    print("Failed to convert JSON string to dictionary: \(error.localizedDescription)")
                }
            } else {
                print("Failed to convert JSON string to Data.")
            }
        }
        
        // Splash sound
        else if (method.rawValue == "playSplashScreenSound") {
            self.playSplashScreenSound();
        }
        
        
        // Default case
        else {
            
        }
    }
    
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func showLockscreenMediaPlayer(title: String, artist: String, albumArtURL: String) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.audioPlayer?.play()
            self?.playerState = .playing
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.audioPlayer?.pause()
            self?.playerState = .paused
            return .success
        }
        
        if(StoryRabbitController.STREAMING_ENABLED){
            self.streamAudioPlayer?.showLockscreenMediaPlayer()
            return;
        }
       
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        
        if let url = URL(string: albumArtURL) {
            downloadImage(from: url) { image in
                if let albumArt = image {
                    let resizedImage = self.resizeImage(image: albumArt, targetSize: CGSize(width: 100, height: 100)) // Adjust target size as needed
                    let albumArtwork = MPMediaItemArtwork(boundsSize: resizedImage.size) { size in
                        return resizedImage
                    }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = albumArtwork
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    func hideLockscreenMediaPlayer(){
        endAudioSession()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.playCommand.isEnabled = false
            commandCenter.pauseCommand.isEnabled = false
            commandCenter.stopCommand.isEnabled = false
            commandCenter.nextTrackCommand.isEnabled = false
            commandCenter.previousTrackCommand.isEnabled = false
    }

    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            let image = UIImage(data: data)
            completion(image)
        }.resume()
    }
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func playNextChapter(){
        if (self.isNewRabbitHole == true) {
            print(
                "New rabbit holes have no next chapters until followup is selected. This is the end.");
            self.playerState = PlayerState.finished;
            return;
        }
        
        self.chapter = self.getNextChapter();
        if (self.chapter != nil) {
            self.playRemoteFile(url: URL(string: self.chapter!.audioUrl!)!)
            self.level = self.level! + 1;
            self.playerState = PlayerState.playing;
        } else {
            print("No next chapter found. This is the end.");
            self.playerState = PlayerState.finished;
        }
    }
    // OLD NON STREAMING ILPLEMENTATION:
    func createRabbithole(payload: String, baseUrl: String, token: String) {
        self.remotePlayed = nil
        self.setRemoteAudioURL(url: nil)
        self.repeatLocalFile()
        
        self.playerState = PlayerState.loading
        playerProgress = self.sendPlayerProgress()
        
        guard let url = URL(string: baseUrl) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        
        guard let jsonData = payload.data(using: .utf8) else {
            return
        }
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                self.handleGeneralError(error)
                return
            }
            
            guard self.handleHTTPStatus(response: response, data: data) else {
                return // Exit if the status code indicates an error
            }
            
            if let data = data {
                DispatchQueue.main.async {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let podcast = try decoder.decode(Podcast.self, from: data)
                        
                        self.level = 0
                        self.rabbithole = podcast
                        self.chapter = podcast
                        self.setRemoteAudioURL(url: URL(string: podcast.audioUrl!))
                        self.playerState = PlayerState.paused
                    } catch let decodingError as DecodingError {
                        self.handleDecodingError(decodingError)
                        self.playerState = PlayerState.finished
                    } catch {
                        self.handleGeneralError(error)
                        self.playerState = PlayerState.finished
                    }
                }
            }
        }
        
        task.resume()
    }
    
    func createFollowUp(baseUrl: String, token: String) {
        self.remotePlayed = nil
        self.setRemoteAudioURL(url: nil)
        self.repeatLocalFile()
        
        self.playerState = PlayerState.loading
        
        guard let url = URL(string: baseUrl) else {
//            result(FlutterError(code: "INVALID_URL", message: "Invalid base URL", details: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                self.handleGeneralError(error)
                return
            }
            
            guard self.handleHTTPStatus(response: response, data: data) else {
                return // Exit if the status code indicates an error
            }
            
            if let data = data {
                DispatchQueue.main.async {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let podcast = try decoder.decode(Podcast.self, from: data)
                        
                        self.level = self.level! + 1
                        self.chapter = podcast
                        self.setRemoteAudioURL(url: URL(string: podcast.audioUrl!))
                       
                    } catch let decodingError as DecodingError {
                        self.handleDecodingError(decodingError)
                    } catch {
                        self.handleGeneralError(error)
                    }
                }
            }
        }
        
        task.resume()
    }
    
    
    func handleHTTPStatus(response: URLResponse?, data: Data?) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        switch httpResponse.statusCode {
        case 200:
            return true
        case 400:
            return false
//            result(FlutterError(code: "BAD_REQUEST", message: "Invalid request. Please check your input and try again.", details: nil))
        case 401:
            return false
//            result(FlutterError(code: "UNAUTHORIZED", message: "You are not authorized. Please log in again.", details: nil))
        case 403:
            return false
            // Handle the 403 error with the custom message and details from the error body
            if let responseData = data {
                do {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
                    
                    // Customize the message based on the entitlementType
                    let entitlementType = errorResponse.data.entitlementType
                    var customMessage = "Access denied."
                    var errorDetails: [String: Any] = ["entitlementType": entitlementType]
                    
                    if entitlementType == "APP" {
                        customMessage = "Premium subscription expired."
                    } else if entitlementType == "PERSONA" {
                        customMessage = "Subscription to host expired."
                        if let personaId = errorResponse.data.personaId {
                            errorDetails["personaId"] = personaId
                        }
                    }
                    
                    // Return the message with details in the FlutterError
                    return false
                } catch {
                    print("responseData \(responseData)")
                    
                    // Handle JSON decoding error
                    return false
                }
            } else {
                // In case there's no data, fall back to the default message
                return false
            }
        case 404:
//            result(FlutterError(code: "NOT_FOUND", message: "The requested resource could not be found.", details: nil))
            return false
        case 500:
//            result(FlutterError(code: "SERVER_ERROR", message: "Something went wrong on our end. Please try again later.", details: nil))
            return false
        default:
//            result(FlutterError(code: "UNKNOWN_ERROR", message: "An unexpected error occurred. Please try again.", details: nil))
            return false
        }
    }
    
    func handleDecodingError(_ error: DecodingError) {
        switch error {
        case .typeMismatch(let type, let context):
            print("Type mismatch error: \(type) in \(context)")
        case .valueNotFound(let value, let context):
            print("Value not found error: \(value) in \(context)")
        case .keyNotFound(let key, let context):
            print("Key not found error: \(key) in \(context)")
        case .dataCorrupted(let context):
            print("Data corrupted error: \(context)")
        @unknown default:
            print("Unknown decoding error")
        }
    }
    
    func handleGeneralError(_ error: Error) {
        print("General error: \(error)")
    }
    
    
    // Use when playing existing rabbit holes
    func getCurrentChapter() -> Podcast? {
        guard let rabbithole = self.rabbithole, let level = self.level else {
            assert(false, "rabbithole and level must not be nil")
            return nil
        }
        
        if level == 0 {
            return rabbithole
        }
        
        return rabbithole.childPodcasts?[level - 1]
    }
    
    func getNextChapter() -> Podcast? {
        guard let rabbithole = self.rabbithole, let level = self.level else {
            assert(false, "rabbithole and level must not be nil")
            return nil
        }
        
        
        if(rabbithole.childPodcasts == nil || rabbithole.childPodcasts!.isEmpty || level>=rabbithole.childPodcasts!.count){
            return nil
        }
        return rabbithole.childPodcasts![level]
        
    }
    
    func playSplashScreenSound() {
        guard let url = Bundle.main.url(forResource: "SPLASH", withExtension: "wav") else {
            print("Unable to find the audio file")
            return
        }
        
        do {
            self.effectsPlayer = try AVAudioPlayer(contentsOf: url)
            self.effectsPlayer?.prepareToPlay()
            self.effectsPlayer?.play()
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func playBellRingSound() {
        guard let url = Bundle.main.url(forResource: "PLAY", withExtension: "wav") else {
            print("Unable to find the audio file")
            return
        }
        
        do {
            self.effectsPlayer = try AVAudioPlayer(contentsOf: url)
            self.effectsPlayer?.prepareToPlay()
            self.effectsPlayer?.play()
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func playRabbithole(baseUrl: String,
                        shareId : String?,
                        id : Int?,
                        startFromChildAt : Int?,
                        token : String ){
        
        
        
        // Fetch podcast
        self.playerState = PlayerState.loading
        
        var url : URL?;
        if(shareId != nil){
            url = URL(string: baseUrl + "public/podcast/"+shareId!)
        } else if(id != nil){
            url = URL(string: baseUrl + "podcast/"+id!.description)
        }
        
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                return
            }
            if let data = data {
                DispatchQueue.main.async {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let podcast = try decoder.decode(Podcast.self, from: data)
                        
                        self.level = startFromChildAt ?? 0
                        self.rabbithole = podcast
                        self.chapter = self.getCurrentChapter()
                        guard let chapter = self.chapter, let audioUrlString = chapter.audioUrl, let audioURL = URL(string: audioUrlString) else {
                            return
                        }
                        self.playRemoteFile(url: audioURL)
                    } catch let decodingError as DecodingError {
                        switch decodingError {
                        case .typeMismatch(let type, let context):
                            print("Type mismatch error: \(type) in \(context)")
                        case .valueNotFound(let value, let context):
                            print("Value not found error: \(value) in \(context)")
                        case .keyNotFound(let key, let context):
                            print("Key not found error: \(key) in \(context)")
                        case .dataCorrupted(let context):
                            print("Data corrupted error: \(context)")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    } catch {
                        print("General decoding error: \(error)")
                    }
                }
            }
            
//            result("play rabbithole finished.")
        }
        task.resume()
        
    }
    
    func sendPlayerProgress()->[String:Any?]? {
        
        // Time for pregenerated audio
        guard let audioPlayer = self.audioPlayer else { return nil }
        let encoder = JSONEncoder()
        let currentTime = CMTimeGetSeconds(audioPlayer.currentTime())
        var playerTime: Int
        if currentTime.isFinite {
            playerTime = Int(round(currentTime))
        } else {
            playerTime = 0
        }
        
        
        // Progress for pregenerated audio
        var progress: [String: Any?] = [
            "playerTime": playerTime,
            "currentChapter": self.chapter != nil ? dictionaryToJsonString(convertToDictionary(self.chapter)!) : nil,
            "currentRabbithole": self.rabbithole != nil ? dictionaryToJsonString(convertToDictionary(self.rabbithole)!) : nil,
            "currentLevel":  self.level,
            "playerState": self.playerState.rawValue
        ]
        
        // Progress for streamed audio
        if(self.isNewRabbitHole==true && StoryRabbitController.STREAMING_ENABLED)
        {progress = self.streamAudioPlayer!.getProgress();}
        return progress
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
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundTask)
        self.backgroundTask = .invalid
    }
    
    
    func addBoundaryTimeObserver() {
        guard let playerItem = self.playerItem else { return }
        
        let duration = playerItem.asset.duration
        let endTime = CMTimeGetSeconds(duration) - 0.5
        
        let time = CMTimeMakeWithSeconds(endTime, preferredTimescale: Int32(NSEC_PER_SEC))
        self.boundaryTimeObserver = self.audioPlayer?.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) { [weak self] in
            self?.checkAndPlayNext()
            print("Boundary time observer triggered")
        }
    }
    
    func stop(){
        if(StoryRabbitController.STREAMING_ENABLED) {self.streamAudioPlayer!.stop();}
        self.lastCompletedLevel = nil;
        self.level = nil;
        self.rabbithole = nil;
        self.chapter = nil;
        self.isNewRabbitHole = nil;
        self.remotePlayed = nil;
        self.effectsPlayer?.pause()
        self.audioPlayer?.pause()
        self.audioPlayer?.seek(to: CMTime.zero)
        self.hideLockscreenMediaPlayer()
        self.endAudioSession()
    }
    
    func checkAndPlayNext() {
        if let remoteURL = remoteAudioURL {
            
            if(self.isNewRabbitHole==true&&self.remotePlayed == true) {
                self.playerState = .finished
                return
            }
            
            if(self.isNewRabbitHole==false){
                self.playNextChapter();
                return
            }
            playRemoteFile(url: remoteURL)
            
        } else {
            repeatLocalFile()
        }
    }
    
    func updateBoundaryTimeObserver() {
        guard let playerItem = self.audioPlayer?.currentItem else { return }
        
        if let observer = self.boundaryTimeObserver {
            self.audioPlayer?.removeTimeObserver(observer)
        }
        
        let duration = playerItem.asset.duration
        let endTime = CMTimeGetSeconds(duration) - 0.5
        
        let time = CMTimeMakeWithSeconds(endTime, preferredTimescale: Int32(NSEC_PER_SEC))
        self.boundaryTimeObserver = self.audioPlayer?.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) { [weak self] in
            self?.checkAndPlayNext()
            print("Boundary time observer updated")
        }
    }
    
    func playRemoteFile(url: URL) {
        self.playBellRingSound()
        
        // Add a delay of 2 seconds before continuing execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
            guard let self = self else { return }
            
            self.remoteAudioURL = url
            let remoteItem = AVPlayerItem(url: url)
            self.audioPlayer?.replaceCurrentItem(with: remoteItem)
            self.updateBoundaryTimeObserver()
            self.audioPlayer?.play()
            self.playerState = .playing
            self.remotePlayed = true
            self.showLockscreenMediaPlayer(
                title: self.chapter?.title ?? "",
                artist: self.rabbithole?.persona?.name ?? "",
                albumArtURL: self.rabbithole?.persona?.pictureUrl ?? ""
            )
        }
    }

    
    func repeatLocalFile() {
        let urls = [self.generatingAudioURL0, self.generatingAudioURL1, self.generatingAudioURL2, self.generatingAudioURL3, self.generatingAudioURL4]
        if let randomURL = urls.randomElement() {
            let localItem = AVPlayerItem(url: randomURL!)
            self.audioPlayer?.replaceCurrentItem(with: localItem)
            self.updateBoundaryTimeObserver()
            self.audioPlayer?.play()
            self.playerState = .loading
            self.hideLockscreenMediaPlayer()
        }
        
    }
    
    func endAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session ended successfully.")

        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
    }
    
    func setRemoteAudioURL(url: URL?) {
        self.remoteAudioURL = url
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            debugPrint("AVAudioSession is Active and Category Playback is set")
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
        } catch {
            debugPrint("Error: \(error)")
        }
    }
    
}
 
