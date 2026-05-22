from appium.webdriver.webdriver import WebDriver
from util.button import reset_item
from util.config import read_config
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, open_input_method_config, scroll_to_id

QUICK_PHRASE_TEXT = "QuickPhraseText"


def test_wbx_string(driver: WebDriver, app: str):
    # Open wbx input method settings from the main screen
    open_input_method_config(driver, "wbx")

    def read_config_value() -> str:
        cfg = read_config(app, "table/wbx.conf")
        return cfg["Table"][QUICK_PHRASE_TEXT]

    # Scroll to QuickPhraseText and get initial value
    field = scroll_to_id(driver, QUICK_PHRASE_TEXT)
    initial_value = field.get_attribute("value")

    # Input "abc"
    field.click()
    field.clear()
    field.send_keys("abc")
    field.send_keys("\n")
    assert field.get_attribute("value") == "abc", UI_NOT_UPDATED
    assert read_config_value() == "abc", CHANGE_NOT_SAVED

    # Test Reset Item
    label = find_element_by_id(driver, f"{QUICK_PHRASE_TEXT}_label")
    reset_item(label)
    assert field.get_attribute("value") == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    # Input "def" without done and navigate back
    field.click()
    field.clear()
    field.send_keys("def")
    driver.back()

    assert read_config_value() == "def", CHANGE_NOT_SAVED
