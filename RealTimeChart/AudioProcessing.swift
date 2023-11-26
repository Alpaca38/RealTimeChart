//
//  AudioProcessing.swift
//  RealTimeChart
//
//  Created by 조규연 on 11/24/23.
//

import AVFoundation
import Accelerate

class AudioProcessing {
    static var shared: AudioProcessing = .init()
    
    private let engine = AVAudioEngine()
    private let bufferSize = 1024
    
    let player = AVAudioPlayerNode()
    // fast fourier transform = 디지털 신호 처리
    var fftMagnitudes: [Float] = []
    
    init() {
        
        _ = engine.mainMixerNode
        
        engine.prepare()
        try! engine.start()
        
        let audioFile = try! AVAudioFile(
            forReading: Bundle.main.url(forResource: "music", withExtension: "mp3")!
        )
        let format = audioFile.processingFormat
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        player.scheduleFile(audioFile, at: nil)
        
        // Digital Signal Processing
        let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(bufferSize),
            vDSP_DFT_Direction.FORWARD
        )
        // Audiofile에 접근 및 처리를 위한 tap 설치
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: UInt32(bufferSize),
            format: nil
        ) { [self] buffer, _ in
                let channelData = buffer.floatChannelData?[0] // 32bit audio sample의 버퍼를 가리키는 포인터
                fftMagnitudes = fft(data: channelData!, setup: fftSetup!)
        }
    }
    
    func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
        // 실수부, 허수부 배열 초기화
        var realIn = [Float](repeating: 0, count: bufferSize)
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        for i in 0..<bufferSize {
            realIn[i] = data[i]
        }
        
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
        var magnitudes = [Float](repeating: 0, count: Constants.barAmount)
        
        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer { imagBP in
                var complex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!) // 복소수 형식의 데이터 구조체
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Constants.barAmount)) // 복소수 배열에서 절대값을 계산해 주파수 성분의 크기를 magnitudes에 저장
            }
        }
        
        var normalizedMagnitudes = [Float](repeating: 0.0, count: Constants.barAmount) // 정규화된 배열 초기화
        var scalingFactor = Float(1)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(Constants.barAmount)) // 정규화
        
        return normalizedMagnitudes
    }
    
    func getCurrentTime() -> TimeInterval {
        if let nodeTime: AVAudioTime = player.lastRenderTime, let playerTime: AVAudioTime = player.playerTime(forNodeTime: nodeTime) {
           return Double(Double(playerTime.sampleTime) / playerTime.sampleRate)
        }
        return 0
    }
    
    func getDuration(_ fileName: String) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: Bundle.main.url(forResource: fileName, withExtension: "mp3")!)
            let audioNodeFileLength = AVAudioFrameCount(audioFile.length)
            return Double(Double(audioNodeFileLength) / audioFile.fileFormat.sampleRate)
        } catch {
            return 0
        }
    }
}
