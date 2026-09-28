# Toy Vision audio

The mission music and sound effects are original procedural compositions for
Toy Vision. `tobi_adventure_loop.wav` is reproducible with:

```powershell
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe run tools/audio_adventure_gen.dart
```

Tobi's Spanish voice clips were synthesized offline with Piper 2023.11.14-2
(MIT) and the `es_ES-carlfm-x_low` voice. Its model card identifies CarlFM's
source dataset as public domain. Neither the TTS runtime nor its model ships in
the application; only the generated PCM WAV clips are bundled.

Generation used:

```text
--length_scale 0.85 --noise_scale 0.62 --noise_w 0.72 --sentence_silence 0.08
```

The exact original phrases are:

- `tobi_session_start.wav`: “¡Vamos! Mueve la cámara despacito. Yo te ayudaré
  a encontrar cada juguete.”
- `tobi_toy_collected.wav`: “¡Sí! ¡Juguete guardado! ¡Buen trabajo!”
- `tobi_almost_finished.wav`: “¡Genial! Ya falta poquito.”
- `tobi_room_verification.wav`: “¡Una última mirada! Muéstrame cada rincón.”
- `tobi_cleanup_completed.wav`: “¡Lo logramos! ¡El cuarto quedó fantástico!”
- `tobi_detection_uncertain.wav`: “Espera un poquito. Estoy mirando otra vez.”

After synthesis, normalize the PCM files with:

```powershell
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe run tools/audio_voice_postprocess.dart
```

- Runtime: https://github.com/rhasspy/piper/releases/tag/2023.11.14-2
- Voice model: https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/es/es_ES/carlfm/x_low
- Model card: https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/es/es_ES/carlfm/x_low/MODEL_CARD

Pinned build inputs (SHA-256):

- Piper Windows archive: `F3C58906402B24F3A96D92145F58ACBA6D86C9B5DB896D207F78DC80811EFCEA`
- `es_ES-carlfm-x_low.onnx`: `D69677323A907CD4963F42B29C20A98B5D6BFA7F3E64DF339915E4650C00D125`
- Voice config: `D9BDFA9FF01EB2BC9E62E7D2593939D1E4C4D8EB7CF75F972731539D12399966`

The phrases are original Toy Vision copy. The voice assets are local feedback;
the app does not record a child, request microphone access, or contact a speech
service at runtime.
