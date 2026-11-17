import unittest

from fetch_lyrics import estimate_words, parse_lrc, parse_lyricsfile, pick_candidate


class EstimateWords(unittest.TestCase):
    def test_words_start_in_order_inside_the_line(self):
        words = estimate_words("my head my heart", 1000, 3000)
        starts = [w["s"] for w in words]
        self.assertEqual(starts[0], 1000)
        self.assertEqual(starts, sorted(starts))
        self.assertLess(starts[-1], 3000)
        self.assertEqual("".join(w["t"] for w in words), "my head my heart")


class ParseLrc(unittest.TestCase):
    def test_skips_blank_and_metadata_lines_and_caps_long_gaps(self):
        lines = parse_lrc("[ar:Someone]\n[00:01.00] Oh\n[00:02.50]\n[01:00.00] Peace, peace\n", 90_000)
        self.assertEqual([l["s"] for l in lines], [1000, 60000])
        self.assertEqual(lines[0]["e"], 2500)  # ends at the blank line
        self.assertLess(lines[1]["words"][-1]["s"], 62_000)  # words not stretched to song end


class ParseLyricsfile(unittest.TestCase):
    def test_reads_real_word_timings_with_yaml_quoting(self):
        doc = """
lines:
- text: I've been tryna call
  start_ms: 27170
  end_ms: 28268
  words:
  - text: 'I''ve '
    start_ms: 27209
  - text: call
    start_ms: 28200
- text: ''
  start_ms: 30000
  end_ms: 31000
"""
        lines = parse_lyricsfile(doc)
        self.assertEqual(len(lines), 1)
        self.assertEqual(lines[0]["words"], [{"t": "I've ", "s": 27209}, {"t": "call", "s": 28200}])


class PickCandidate(unittest.TestCase):
    def test_prefers_word_sync_within_duration_tolerance(self):
        cands = [
            {"id": 1, "duration": 200.0, "syncedLyrics": "x", "hasWordSync": False},
            {"id": 2, "duration": 202.0, "syncedLyrics": "x", "hasWordSync": True},
            {"id": 3, "duration": 260.0, "syncedLyrics": "x", "hasWordSync": True},
            {"id": 4, "duration": 200.0, "syncedLyrics": None},
        ]
        self.assertEqual(pick_candidate(cands, 200)["id"], 2)
        self.assertIsNone(pick_candidate(cands, 400))


if __name__ == "__main__":
    unittest.main()
