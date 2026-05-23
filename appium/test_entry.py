import os

from appium.webdriver.webdriver import WebDriver
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import (
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to_id,
)
from util.string import get_string_value

IDS = ["Key", "Mapping", "AltMapping"]
ORIGINAL_VALUES = [".", "。", ""]
VALUES = ["*", r"\times", r"\dot"]


def test_punctuation_map(driver: WebDriver, app: str) -> None:
    open_input_method_config(driver, "pinyin")
    scroll_to_id(driver, "Punctuation").click()

    def read_config_value() -> str:
        punc_path = os.path.join(app, "../data/punctuation/punc.mb.zh_CN")
        with open(punc_path, "r") as f:
            return f.readline().rstrip()

    for id, value in zip(IDS, VALUES):
        field = find_elements_by_id(driver, id)[0]
        field.click()
        field.clear()
        field.send_keys(value)
        field.send_keys("\n")

    for id, value in zip(IDS, VALUES):
        field = find_elements_by_id(driver, id)[0]
        assert get_string_value(field) == value, UI_NOT_UPDATED

    assert read_config_value() == " ".join(VALUES), CHANGE_NOT_SAVED

    find_element_by_id(driver, "ResetList").click()
    for id, value in zip(IDS, ORIGINAL_VALUES):
        field = find_elements_by_id(driver, id)[0]
        assert get_string_value(field) == value, UI_NOT_UPDATED

    assert read_config_value() == " ".join(ORIGINAL_VALUES).rstrip(), CHANGE_NOT_SAVED
