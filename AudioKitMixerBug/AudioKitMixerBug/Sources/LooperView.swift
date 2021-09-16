import AudioKit
import AudioKitEX
import AVFoundation
import SwiftUI

class LooperConductor: ObservableObject {

	var tempo = 120.0
	var loopLengthInNumberOfBeats = 16

	@Published var debugText = ""

	private let engine = AudioEngine()
	private let mixer = Mixer()
	private let sequencer = Sequencer()

	private var callbackInstrument: CallbackInstrument?

	private var audioFiles: [String: AVAudioFile] = [:]
	private var midiSamplers: [String: MIDISampler] = [:]
	private var sequencerTracks: [String: SequencerTrack] = [:]

	let samples: [String] =
		[
			"Audio/Loops/Thick Gritty Bass.caf",
			"Audio/DrumLoop/BassAndSnare120Bpm-simple.caf",
		]

	init() {
		engine.output = mixer
		sequencer.tempo = tempo

		setupBeatCounter()

		loadAudioFiles(pathOfAudioFiles: samples)
	}

	func togglePlaySequencer() {
		sequencer.isPlaying ? sequencer.stop() : sequencer.play()
	}

	// MARK: - Beat Counter Methods

	private func setupBeatCounter() {

		// configure instrument
		let callbackInstrument = CallbackInstrument(midiCallback: { status, beat, _ in

			guard let midiStatus = MIDIStatusType.from(byte: status) else {
				return
			}

			if midiStatus == .noteOn {
				self.debugText = "\(Int(beat))"
			}
		})

		self.callbackInstrument = callbackInstrument


		// BUG: Causes the last mixer channel / MIDISAmpler to flange (because its playing twice?)
		mixer.addInput(callbackInstrument)

		// WORKAROUND:
		//		let mixer2 = Mixer()
		//		mixer2.addInput(callbackInstrument)
		//		mixer.addInput(mixer2)

		// configure track for instrument
		let track = sequencer.addTrack(for: callbackInstrument)

		track.length = Double(loopLengthInNumberOfBeats)
		track.clear()
		for beat in 0 ..< loopLengthInNumberOfBeats {
			track.sequence.add(noteNumber: MIDINoteNumber(beat), position: Double(beat), duration: 0.1)
		}
	}

	// MARK: - Audio Loop Methods

	func loadAudioFiles(pathOfAudioFiles: [String]) {

		for path in pathOfAudioFiles {

			guard let url = Bundle.main.resourceURL?.appendingPathComponent(path) else {
				assertionFailure("could create url")
				continue
			}

			do {
				let audioFile = try AVAudioFile(forReading: url)
				let midiSampler = MIDISampler()
				try midiSampler.loadAudioFile(audioFile)

				let filePath = path

				audioFiles[filePath] = audioFile
				midiSamplers[filePath] = midiSampler

				mixer.addInput(midiSampler)

				let track = sequencer.addTrack(for: midiSampler)
				track.length = Double(loopLengthInNumberOfBeats)
				track.clear()
				sequencerTracks[filePath] = track

			} catch {
				print("could not load file \(error)")
				continue
			}
		}
	}

	func scheduleAudioLoop(path: String) {
		guard let track = sequencerTracks[path] else {
			print("play not possible. file not found in sequencerTracks")
			return
		}
		track.clear()
		track.sequence.add(noteNumber: MIDINoteNumber(60), position: Double(0), duration: 15.99)
	}

	// MARK: - Engine Methods

	func start() {
		do {
			try engine.start()
		} catch let err {
			Log(err)
		}
	}

	func stop() {
		sequencer.stop()
		engine.stop()
	}
}

struct LooperView: View {

	@StateObject var conductor = LooperConductor()

	var body: some View {

		VStack {
			Text(conductor.debugText)
			Button("Play") {

				conductor.scheduleAudioLoop(path: "Audio/DrumLoop/BassAndSnare120Bpm-simple.caf")
				conductor.togglePlaySequencer()
			}
		}
		.onAppear {
			conductor.start()
		}
		.onDisappear {
			conductor.stop()
		}
	}
}
