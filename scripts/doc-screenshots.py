from seleniumbase import BaseCase


class BenchCIScreenshots(BaseCase):
    def test_capture_screenshots(self):
        self.set_window_size(1920, 1080)
        self.open("https://bench.ci.dev/")

        self.click('select[name="repositories"]')
        self.save_screenshot("doc/screenshots/side-bar.png")

        # Select "ocaml/dune"
        self.click('option[value="ocaml/dune"]')
        self.wait_for_element('a:contains("View Logs")')
        self.save_screenshot("doc/screenshots/main.png")

        # Select the first PR
        self.click('a:contains("#")')
        self.wait_for_element('a:contains("main")')
        self.wait(7)
        self.save_screenshot("doc/screenshots/pr.png")


if __name__ == "__main__":
    BenchCIScreenshots.main(__name__, __file__)
