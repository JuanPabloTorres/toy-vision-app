"""Map open-vocabulary detector labels to the ToyVision registry labels.

The registry is the single source of truth on the Flutter side
(`ToyCategoryRegistry`). YOLO-World / Grounding DINO emit free-text labels
that depend on the prompts list; this module collapses them to the small
set of registry labels.
"""
from __future__ import annotations

# The canonical 14 labels the Flutter business layer knows about.
REGISTRY_LABELS = {
    "toy_car",
    "toy_truck",
    "doll",
    "stuffed_animal",
    "building_blocks",
    "ball",
    "action_figure",
    "toy_train",
    "puzzle",
    "board_game",
    "not_toy",
    "person",
    "pet",
    "book",
}

# Prompt strings the server sends to YOLO-World (Phase 5.0.1). The keys are
# the lowercase detector outputs; values are the registry labels.
# Add aliases here as we discover what the open-vocabulary model prefers.
_LABEL_MAP = {
    # Toys
    "toy car": "toy_car",
    "car": "toy_car",
    "toy truck": "toy_truck",
    "truck": "toy_truck",
    "doll": "doll",
    "stuffed animal": "stuffed_animal",
    "teddy bear": "stuffed_animal",
    "plush": "stuffed_animal",
    "building blocks": "building_blocks",
    "blocks": "building_blocks",
    "lego": "building_blocks",
    "ball": "ball",
    "action figure": "action_figure",
    "figure": "action_figure",
    "toy train": "toy_train",
    "train": "toy_train",
    "puzzle": "puzzle",
    "board game": "board_game",
    # Negatives / ignored
    "book": "book",
    "person": "person",
    "human": "person",
    "child": "person",  # mapped to person; business layer drops it
    "dog": "pet",
    "cat": "pet",
    "pet": "pet",
}

# The fixed prompts the placeholder server reports as "supported". These
# match the labels YOLO-World will be prompted with in Phase 5.0.1.
SUPPORTED_PROMPTS = [
    "toy",
    "toy car",
    "toy truck",
    "ball",
    "stuffed animal",
    "doll",
    "building blocks",
    "action figure",
    "toy train",
    "puzzle",
    "board game",
    "book",
    "person",
    "pet",
]


def to_registry_label(raw_label: str) -> str:
    """Translate one detector output string to a registry label.

    Unknown strings fall back to ``"not_toy"`` so the business layer treats
    them as ignorable but visible-to-debug. The registry contains a single
    ``"unknown"`` value that is reserved for the fallback inside the Dart
    layer; the server never emits that.
    """
    key = (raw_label or "").strip().lower()
    return _LABEL_MAP.get(key, "not_toy")
