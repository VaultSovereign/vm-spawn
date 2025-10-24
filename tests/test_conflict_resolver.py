"""Tests for conflict resolver determinism and parsing."""
import random

from src.conflict_resolver import resolve


def test_deterministic_winner():
    base = [
        {"chain": "EVM", "anchorTs": "2025-10-24T12:00:02Z", "txHash": "0x2"},
        {"chain": "BTC", "anchorTs": "2025-10-24T12:00:03Z", "txHash": "0x1"},
        {"chain": "TSA", "anchorTs": "2025-10-24T12:00:01Z", "txHash": "0x3"},
    ]
    winners = []
    for _ in range(50):
        payloads = base[:]
        random.shuffle(payloads)
        winners.append(resolve(payloads)["chain"])

    assert set(winners) == {"BTC"}


def test_timezone_naive_parses():
    receipts = [
        {"chain": "EVM", "anchorTs": "2025-10-24T12:00:00", "txHash": "0x1"},
        {"chain": "EVM", "anchorTs": "2025-10-24T12:00:00Z", "txHash": "0x0"},
    ]

    assert resolve(receipts)["txHash"] == "0x0"
