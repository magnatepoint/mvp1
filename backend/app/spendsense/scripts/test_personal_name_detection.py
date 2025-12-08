"""
Quick test script to verify personal name detection works for known names.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from app.spendsense.services.category_inference import _looks_like_personal_name

# Test cases from the analysis
test_cases = [
    ("mudavath", True, "Should be detected as personal name"),
    ("rehana", True, "Should be detected as personal name"),
    ("sudarsha", True, "Should be detected as personal name"),
    ("chintala", True, "Should be detected as personal name"),
    ("vijetha", True, "Should be detected as personal name"),
    ("2 hp pet", False, "Has digits - should NOT be detected as name"),
    ("int", False, "Abbreviation - should NOT be detected"),
    ("amazon", False, "Known merchant - should NOT be detected"),
    ("p n v l praneet", True, "Initials + name - should be detected"),
    ("by transfer-imps/529516578056/hsb-xx001-cams/87070", False, "Transaction ID - should NOT be detected"),
]

print("Testing Personal Name Detection:")
print("=" * 80)

for text, expected, description in test_cases:
    result = _looks_like_personal_name(text)
    status = "✅" if result == expected else "❌"
    print(f"{status} '{text}' → {result} (expected: {expected}) - {description}")

print("=" * 80)

