"""Face-frame textures for the cast: the same painted head with the eyes closed (blink), the mouth part / wide open (talking) and the brows raised.
The game swaps the head material's texture between them (scripts/art/face_anim.gd), so characters blink, talk and react in the same
pixel style, with no extra geometry or bones.

    python tools/character_cast/paint_faces.py [Name ...]        # default: everyone  ->  assets/characters/faces/<Name>_<frame>.png
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paint_cast as P
from cast_specs import CAST

REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(REPO, "assets", "characters", "faces")
FRAMES = {
    "blink": {"blink": True},
    "m1": {"mouth": 1},                    # lips parted
    "m2": {"mouth": 2},                    # open wide
    "brow": {"brow": True},                # brows raised (an accent, a question)
    "browm1": {"brow": True, "mouth": 1},
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(CAST)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        for key, pose in FRAMES.items():
            P.paint_head(name, CAST[name], pose).save(os.path.join(OUT, "%s_%s.png" % (name, key)))
    print("face frames for", len(names), "characters ->", OUT)
