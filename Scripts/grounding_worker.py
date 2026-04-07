#!/usr/bin/env python3

import argparse
import base64
import io
import json
import sys
import traceback
from typing import Any


def emit(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def eprint(message: str) -> None:
    sys.stderr.write(message + "\n")
    sys.stderr.flush()


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def normalize_box(box: dict[str, float], width: int, height: int) -> list[float] | None:
    if width <= 0 or height <= 0:
        return None

    xmin = clamp(float(box.get("xmin", 0.0)), 0.0, float(width))
    ymin = clamp(float(box.get("ymin", 0.0)), 0.0, float(height))
    xmax = clamp(float(box.get("xmax", 0.0)), 0.0, float(width))
    ymax = clamp(float(box.get("ymax", 0.0)), 0.0, float(height))

    if xmax <= xmin or ymax <= ymin:
        return None

    return [
        xmin / width,
        ymin / height,
        (xmax - xmin) / width,
        (ymax - ymin) / height,
    ]


def load_detector(model_id: str):
    try:
        import torch  # noqa: F401
        from transformers import pipeline
    except Exception as exc:  # pragma: no cover - runtime dependency error
        raise RuntimeError(
            "Missing grounding worker dependencies. Install requirements-grounding.txt first."
        ) from exc

    return pipeline(
        task="zero-shot-object-detection",
        model=model_id,
        device=-1,
    )


def handle_detect(detector, request: dict[str, Any], default_threshold: float, default_top_k: int) -> dict[str, Any]:
    try:
        from PIL import Image
    except Exception as exc:  # pragma: no cover - runtime dependency error
        raise RuntimeError(
            "Pillow is required for grounding worker image decoding."
        ) from exc

    frame = request.get("frame", {})
    image_bytes = base64.b64decode(frame["jpeg_base64"])
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    width = int(frame.get("width") or image.width)
    height = int(frame.get("height") or image.height)

    candidate_queries = request.get("candidate_queries") or []
    if not candidate_queries:
        candidate_queries = [request.get("target_description", "target")]

    threshold = float(request.get("score_threshold", default_threshold))
    top_k = int(request.get("top_k", default_top_k))

    predictions = detector(
        image,
        candidate_labels=candidate_queries,
        threshold=threshold,
    )

    predictions = sorted(predictions, key=lambda item: float(item.get("score", 0.0)), reverse=True)

    detections: list[dict[str, Any]] = []
    for prediction in predictions[:top_k]:
        normalized_box = normalize_box(prediction.get("box", {}), width, height)
        if normalized_box is None:
            continue

        label = str(prediction.get("label", "target"))
        detections.append(
            {
                "query": label,
                "label": label,
                "confidence": float(prediction.get("score", 0.0)),
                "bbox": normalized_box,
            }
        )

    return {
        "type": "result",
        "request_id": request.get("request_id"),
        "detections": detections,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="CallDP local grounding worker")
    parser.add_argument("--model", default="google/owlv2-base-patch16-ensemble")
    parser.add_argument("--threshold", type=float, default=0.12)
    parser.add_argument("--top-k", type=int, default=3)
    args = parser.parse_args()

    try:
        detector = load_detector(args.model)
    except Exception as exc:
        eprint(f"Failed to initialize grounding model: {exc}")
        traceback.print_exc(file=sys.stderr)
        return 1

    emit(
        {
            "type": "ready",
            "model_id": args.model,
            "message": "grounding worker ready",
        }
    )

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            payload = json.loads(line)
            request_type = payload.get("type")

            if request_type != "detect":
                emit(
                    {
                        "type": "error",
                        "request_id": payload.get("request_id"),
                        "message": f"Unsupported request type: {request_type}",
                    }
                )
                continue

            emit(handle_detect(detector, payload, args.threshold, args.top_k))
        except Exception as exc:  # pragma: no cover - runtime fault path
            request_id = None
            try:
                request_id = payload.get("request_id")  # type: ignore[name-defined]
            except Exception:
                request_id = None

            emit(
                {
                    "type": "error",
                    "request_id": request_id,
                    "message": str(exc),
                }
            )
            traceback.print_exc(file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
