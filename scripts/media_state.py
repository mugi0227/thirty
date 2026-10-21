"""Read the current Apple processing state for screenshots and previews."""


def delivery_state(attributes, *, video=False):
    # App Store Connect API 3.7 deprecated assetDeliveryState for previews.
    # A modern failure/pending state must never fall back to legacy COMPLETE.
    if video:
        current = attributes.get("videoDeliveryState") or {}
        if current.get("state"):
            return current["state"]
    return (attributes.get("assetDeliveryState") or {}).get("state")
