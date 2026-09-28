# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "parler-tts @ git+https://github.com/huggingface/parler-tts.git@d108732cd57788ec86bc857d99a6cabd66663d68",
#   "soundfile==0.13.1",
#   "torch==2.14.0",
# ]
# [tool.uv.sources]
# torch = { index = "pytorch-cu130" }
# [[tool.uv.index]]
# name = "pytorch-cu130"
# url = "https://download.pytorch.org/whl/cu130"
# explicit = true
# ///
"""Generate Tobi's fixed Spanish phrases with a synthetic child character."""

import argparse
from pathlib import Path

import soundfile as sf
import torch
from parler_tts import ParlerTTSForConditionalGeneration
from transformers import AutoTokenizer

MODEL_ID = "parler-tts/parler-tts-mini-multilingual-v1.1"
MODEL_REVISION = "11b27d57855dec1ce0914ba1f12363bf2ea75ba3"
DESCRIPTION_TOKENIZER_ID = "google/flan-t5-large"
DESCRIPTION_TOKENIZER_REVISION = "0613663d0d48ea86ba8cb3d7a44f0f65dc596a2a"
OUTPUT_DIR = Path("assets/audio")
DESCRIPTION = (
    "Olivia has the unmistakably bright, high-pitched voice of a cheerful young "
    "girl. She speaks Spanish clearly with a playful, warm, lively delivery, like a "
    "friendly little robot in a children's game. Her pace is moderate. The recording "
    "is very clear, close, dry, and has no background noise or reverberation."
)
CLIPS = {
    "tobi_session_start.wav": (
        "Vamos, mueve la cámara despacito, yo te ayudo a encontrar cada juguete."
    ),
    "tobi_toy_collected.wav": "Sí, lo guardaste, buen trabajo.",
    "tobi_almost_finished.wav": "Genial, ya falta poquito.",
    "tobi_room_verification.wav": ("Una última mirada. Muéstrame cada rincón."),
    "tobi_cleanup_completed.wav": ("Lo logramos. El cuarto quedó fantástico."),
    "tobi_detection_uncertain.wav": ("Espera un poquito. Estoy mirando otra vez."),
}
SEEDS = {
    "tobi_session_start.wav": 5000,
    "tobi_toy_collected.wav": 5100,
    "tobi_almost_finished.wav": 4102,
    "tobi_room_verification.wav": 4103,
    "tobi_cleanup_completed.wav": 4104,
    "tobi_detection_uncertain.wav": 4105,
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*", choices=CLIPS.keys())
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--attempts", type=int, default=1)
    args = parser.parse_args()

    if not torch.cuda.is_available():
        raise RuntimeError("A CUDA GPU is required for the pinned voice generator")

    device = torch.device("cuda:0")
    model = ParlerTTSForConditionalGeneration.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        torch_dtype=torch.bfloat16,
        attn_implementation="eager",
    ).to(device)
    prompt_tokenizer = AutoTokenizer.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
    )
    description_tokenizer = AutoTokenizer.from_pretrained(
        DESCRIPTION_TOKENIZER_ID,
        revision=DESCRIPTION_TOKENIZER_REVISION,
    )
    description_tokens = description_tokenizer(
        DESCRIPTION,
        return_tensors="pt",
    ).to(device)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    selected = args.only or list(CLIPS)
    for filename in selected:
        phrase = CLIPS[filename]
        prompt_tokens = prompt_tokenizer(
            phrase,
            return_tensors="pt",
        ).to(device)
        base_seed = args.seed if args.seed is not None else SEEDS[filename]
        for attempt in range(args.attempts):
            seed = base_seed + attempt
            torch.manual_seed(seed)
            with torch.inference_mode():
                generated = model.generate(
                    input_ids=description_tokens.input_ids,
                    attention_mask=description_tokens.attention_mask,
                    prompt_input_ids=prompt_tokens.input_ids,
                    prompt_attention_mask=prompt_tokens.attention_mask,
                    do_sample=True,
                    temperature=0.8,
                )
            samples = generated.detach().float().cpu().numpy().squeeze()
            output_name = (
                filename
                if args.attempts == 1
                else f"{Path(filename).stem}_seed{seed}.wav"
            )
            output = args.output_dir / output_name
            sf.write(
                output,
                samples,
                model.config.sampling_rate,
                subtype="PCM_16",
            )
            print(
                f"[voice] generated {output} seed={seed} "
                f"({len(samples) / model.config.sampling_rate:.2f}s)"
            )


if __name__ == "__main__":
    main()
