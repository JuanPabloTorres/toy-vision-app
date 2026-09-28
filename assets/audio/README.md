# Toy Vision audio

The mission music and sound effects are original procedural compositions for
Toy Vision. `tobi_adventure_loop.wav` is reproducible with:

```powershell
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe run tools/audio_adventure_gen.dart
```

Tobi's Spanish voice clips are synthesized offline with Parler-TTS Mini
Multilingual v1.1. The model and generator are Apache 2.0 licensed. The model
supports Spanish and text descriptions for pitch, age, pace and delivery.
Neither the Python runtime nor the 3.75 GB model ships in the application;
only the generated mono PCM WAV clips are bundled.

Generate the pinned clips on a CUDA-capable development machine, then trim and
normalize them without altering the synthesized timbre:

```powershell
C:\Users\estju\.local\bin\uv.exe run --python 3.11 tools/generate_tobi_voice.py
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe run tools/audio_voice_postprocess.dart
```

The generator pins the model revision, Python dependencies and accepted seed
for each phrase. Its character description asks for Olivia to speak in the
bright, high-pitched voice of a cheerful young girl with a playful robot-game
delivery. The exact phrases are:

- `tobi_session_start.wav`: “Vamos, mueve la cámara despacito, yo te ayudo a
  encontrar cada juguete.”
- `tobi_toy_collected.wav`: “Sí, lo guardaste, buen trabajo.”
- `tobi_almost_finished.wav`: “Genial, ya falta poquito.”
- `tobi_room_verification.wav`: “Una última mirada. Muéstrame cada rincón.”
- `tobi_cleanup_completed.wav`: “Lo logramos. El cuarto quedó fantástico.”
- `tobi_detection_uncertain.wav`: “Espera un poquito. Estoy mirando otra vez.”

- Model: https://huggingface.co/parler-tts/parler-tts-mini-multilingual-v1.1
- Generator: https://github.com/huggingface/parler-tts
- Model license: Apache 2.0

The phrases are original Toy Vision copy. The voice assets are local feedback;
the app does not record a child, request microphone access, or contact a speech
service at runtime.
