from urllib.parse import quote, urlencode

from appium.webdriver.webdriver import WebDriver
from conftest import BUNDLE_ID
from selenium.webdriver.support.ui import WebDriverWait
from util.screen import find_element_by_id

EDIT_TEXT = "ClipboardEditText"
EDIT_REQUESTS = (
    ("00000000-0000-0000-0000-000000000001", "First clipboard item\n第一项"),
    ("00000000-0000-0000-0000-000000000002", "Second clipboard item\n第二项"),
)


def test_switch_open_clipboard_editor(driver: WebDriver, app: str) -> None:
    # URL payloads are sufficient to open the editor; never save these test items.
    for identity, text in (*EDIT_REQUESTS, EDIT_REQUESTS[0]):
        # Leave the previous editor open while returning to the input host.
        driver.activate_app("com.apple.MobileSMS")
        query = urlencode({"id": identity, "text": text}, quote_via=quote)
        driver.execute_script(
            "mobile: deepLink",
            {"url": f"fcitx://clipboard/edit?{query}", "bundleId": BUNDLE_ID},
        )
        WebDriverWait(driver, 10).until(
            lambda _, expected=text: (
                find_element_by_id(driver, EDIT_TEXT).get_attribute("value") == expected
            )
        )
