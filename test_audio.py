import unittest

import numpy as np

from audio import BLOCK, RATE, BassMeter


def tone(hz: float, blocks: int, amplitude: float = 0.5) -> list[np.ndarray]:
    t = np.arange(BLOCK * blocks) / RATE
    return np.split((amplitude * np.sin(2 * np.pi * hz * t)).astype(np.float32), blocks)


def last_level(meter: BassMeter, blocks: list[np.ndarray]) -> float:
    for b in blocks:
        level = meter.feed(b)
    return level


class BassMeterTest(unittest.TestCase):
    def test_silence_is_zero(self):
        self.assertEqual(last_level(BassMeter(), [np.zeros(BLOCK, np.float32)] * 5), 0.0)

    def test_steady_bass_is_full(self):
        self.assertGreater(last_level(BassMeter(), tone(60, 10)), 0.9)

    def test_treble_is_zero(self):
        self.assertEqual(last_level(BassMeter(), tone(2000, 10)), 0.0)

    def test_quiet_bass_after_loud_bass_is_low(self):
        meter = BassMeter()
        last_level(meter, tone(60, 10, 0.8))
        self.assertLess(last_level(meter, tone(60, 3, 0.1)), 0.3)


if __name__ == "__main__":
    unittest.main()
