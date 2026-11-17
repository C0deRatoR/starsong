import io
import unittest

from PIL import Image

from media import album_colors


class AlbumColors(unittest.TestCase):
    def test_most_common_colour_first(self):
        image = Image.new("RGB", (100, 100), (200, 30, 30))
        image.paste((20, 40, 220), (0, 0, 100, 30))  # a smaller blue band
        data = io.BytesIO()
        image.save(data, "PNG")
        colors = album_colors(data.getvalue())
        self.assertEqual(colors[:2], ["#c81e1e", "#1428dc"])


if __name__ == "__main__":
    unittest.main()
