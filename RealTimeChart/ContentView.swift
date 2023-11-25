//
//  ContentView.swift
//  RealTimeChart
//
//  Created by 조규연 on 11/24/23.
//

import Charts
import SwiftUI
import AVFAudio

enum Constants {
    static let updateInterval = 0.03
    static let barAmount = 40
    static let magnitudeLimit: Float = 32
}

struct ContentView: View {
    let audioProcessing = AudioProcessing.shared
    
    @State var progress: Double = 0.0
//    @State var currentTime: Double = 0.0
    @State var isPlaying = false
    @State var data: [Float] = Array(repeating: 0, count: Constants.barAmount)
        .map { _ in Float.random(in: 1...Constants.magnitudeLimit) }
    
    var body: some View {
        let timer = Timer.publish(
            every: Constants.updateInterval,
            on: .main,
            in: .common
        ).autoconnect()
        
        VStack {
            Spacer()
            
            VStack {
                Chart(Array(data.enumerated()), id: \.0) { index, magnitude in
                    BarMark(
                        x: .value("Frequency", String(index)),
                        y: .value("Magnitude", magnitude)
                    )
                    .foregroundStyle(
                        Color(
                            hue: 0.3 - Double(magnitude / Constants.magnitudeLimit / 5),
                            saturation: 1,
                            brightness: 1,
                            opacity: 0.7
                        )
                    )
                }
                .onReceive(timer, perform: updateData)
                .chartYScale(domain: 0...Constants.magnitudeLimit)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 100)
                .padding()
                .background(
                    .black
                        .opacity(0.3)
                        .shadow(.inner(radius: 20))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                playerControls
                    .onReceive(timer, perform: updateProgress)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 40)
            .padding()
        }
        .background {
            backgroundPicture
        }
        .preferredColorScheme(.dark)
    }
    
    var backgroundPicture: some View {
        AsyncImage(
            url: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/6/6f/Beethoven.jpg"
            ),
            transaction: Transaction(animation: .easeOut(duration: 1))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Color.clear
            }
        }
        .overlay {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    var playerControls: some View {
        Group {
            ProgressView(value: progress)
                .tint(.secondary)
            Text("Beethoven Symphony No. 5 in C minor, Op. 67")
                .font(.title2)
                .lineLimit(1)
            Text("Ludwig van Beethovan")
            
            Button(action: playButtonTapped) {
                Image(systemName: "\(isPlaying ? "pause" : "play").circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
            }
        }
    }
    
    func playButtonTapped() {
        if isPlaying {
            audioProcessing.player.pause()
        } else {
            audioProcessing.player.play()
        }
        isPlaying.toggle()
    }
    
    func updateData(_: Date) {
        if isPlaying {
            withAnimation(.easeOut(duration: 0.08)) {
                data = audioProcessing.fftMagnitudes.map {
                    min($0, Constants.magnitudeLimit)
                }
            }
        }
    }
    
    func updateProgress(_: Date) {
        if isPlaying {
            var currentTime = getCurrentTime()
            let duration = getDuration("music")
            progress = currentTime / Double(duration)
        }
    }
    
    func getCurrentTime() -> TimeInterval {
        if let nodeTime: AVAudioTime = audioProcessing.player.lastRenderTime, let playerTime: AVAudioTime = audioProcessing.player.playerTime(forNodeTime: nodeTime) {
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

#Preview {
    ContentView()
}
