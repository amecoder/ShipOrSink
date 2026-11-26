"""Property-based testing example (Hypothesis) — common/rules/testing.md.

Copy to tests/test_property_example.py and replace split_amount with your own code.
An example test checks inputs you picked; a property test states what must hold for
*every* input, lets Hypothesis search for a counterexample, and shrinks it.

Run: pytest tests/test_property_example.py   (needs `hypothesis` as a dev dependency)
Checked by tests/enforcement-pbt.bats: it injects a bug the example below misses and
expects the property test to fail with a "Failing test case".
"""

from __future__ import annotations

from hypothesis import given
from hypothesis import strategies as st


def split_amount(total_cents: int, parts: int) -> list[int]:
    """Split total_cents into `parts` shares that differ by at most one cent."""
    if parts <= 0:
        raise ValueError("parts must be positive")
    base, remainder = divmod(total_cents, parts)
    return [base + 1] * remainder + [base] * (parts - remainder)


totals = st.integers(min_value=0, max_value=10**12)
part_counts = st.integers(min_value=1, max_value=1000)


@given(total=totals, parts=part_counts)
def test_shares_add_up_to_total(total: int, parts: int) -> None:
    assert sum(split_amount(total, parts)) == total


@given(total=totals, parts=part_counts)
def test_shares_are_fair(total: int, parts: int) -> None:
    shares = split_amount(total, parts)
    assert len(shares) == parts
    assert max(shares) - min(shares) <= 1


def test_example_still_documents_intent() -> None:
    # keep one readable example next to the properties — it explains the rule to a human
    assert split_amount(100, 3) == [34, 33, 33]
