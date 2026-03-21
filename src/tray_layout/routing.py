from dataclasses import dataclass


@dataclass
class RoutingDecision:
    use_classifier_layout: bool
    confidence: float
    threshold: float
    reason: str


def choose_layout_route(confidence: float, threshold: float = 1.0) -> RoutingDecision:
    if confidence >= threshold:
        return RoutingDecision(
            use_classifier_layout=True,
            confidence=confidence,
            threshold=threshold,
            reason="tray classifier confidence above threshold",
        )

    return RoutingDecision(
        use_classifier_layout=False,
        confidence=confidence,
        threshold=threshold,
        reason="tray classifier confidence below threshold; use CV fallback",
    )
