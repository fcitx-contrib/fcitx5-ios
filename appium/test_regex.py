from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.config import read_config
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED, UI_WRONGLY_UPDATED
from util.screen import (
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to_id,
)

QUICK_PHRASE_REGEX = "QuickPhraseTriggerRegex"
AUTO_SELECT_REGEX = "AutoSelectRegex"


def perform_actions(field: WebElement):
    driver = field.parent

    def has_error_message():
        return len(find_elements_by_id(driver, "InvalidRegex")) > 0

    field.click()
    assert not has_error_message(), UI_WRONGLY_UPDATED

    field.clear()
    field.send_keys("[")
    assert has_error_message(), UI_NOT_UPDATED

    field.send_keys("a]")
    assert not has_error_message(), UI_NOT_UPDATED

    # Dismiss the keyboard to blur and commit.
    field.send_keys("\n")
    assert not has_error_message(), UI_WRONGLY_UPDATED


def test_regex_list(driver: WebDriver, app: str):
    open_input_method_config(driver, "pinyin")

    def read_config_value():
        cfg = read_config(app, "conf/pinyin.conf")
        return cfg[QUICK_PHRASE_REGEX][str(len(cfg[QUICK_PHRASE_REGEX]) - 1)]

    scroll_to_id(driver, QUICK_PHRASE_REGEX).click()
    find_element_by_id(driver, "plus").click()
    field = find_elements_by_id(driver, QUICK_PHRASE_REGEX)[-1]
    perform_actions(field)
    assert read_config_value() == "[a]", CHANGE_NOT_SAVED


def test_regex_string(driver: WebDriver, app: str):
    open_input_method_config(driver, "wbx")

    def read_config_value():
        cfg = read_config(app, "table/wbx.conf")
        return cfg["Table"][AUTO_SELECT_REGEX]

    field = scroll_to_id(driver, AUTO_SELECT_REGEX)
    perform_actions(field)
    assert read_config_value() == "[a]", CHANGE_NOT_SAVED
