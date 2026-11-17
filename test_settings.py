import unittest

from settings import merge

DEFAULTS = {"style": "constellation", "textScale": 1.0, "fontWeight": 500, "glow": True}


class Merge(unittest.TestCase):
    def test_keeps_known_values_of_the_right_type(self):
        saved = {"style": "karaoke", "textScale": 1, "fontWeight": 700, "glow": False}
        self.assertEqual(merge(saved, DEFAULTS), saved)

    def test_drops_unknown_and_mistyped_values(self):
        with self.assertLogs("settings", "WARNING"):
            merged = merge({"style": 3, "glow": "yes", "fontWeight": True, "nope": 1}, DEFAULTS)
        self.assertEqual(merged, DEFAULTS)

    def test_not_an_object_gives_defaults(self):
        with self.assertLogs("settings", "WARNING"):
            self.assertEqual(merge([1, 2], DEFAULTS), DEFAULTS)


if __name__ == "__main__":
    unittest.main()
