import Foundation
import SwiftUI
import AVFoundation

#if canImport(Speech)
import Speech
#endif

@MainActor
class SpeechTranscriber: ObservableObject {
    #if canImport(Speech)
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var transcript = ""
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))
        super.init()
    }
    
    func requestPermissions() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func ensureAuthorization() async -> Bool {
        return await requestPermissions()
    }
    
    func startTranscribing() {
        startRecording()
    }
    
    func stopTranscribing() {
        stopRecording()
    }
    
    var errorMessage: String? {
        return nil
    }
    
    func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.record)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.transcription = text
                    self.transcript = text
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
        
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    #else
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var transcript = ""
    
    func requestPermissions() async -> Bool { false }
    func ensureAuthorization() async -> Bool { false }
    func startRecording() {}
    func stopRecording() {}
    func startTranscribing() {}
    func stopTranscribing() {}
    
    var errorMessage: String? {
        return "Speech recognition is not available on this platform"
    }
    #endif
}
