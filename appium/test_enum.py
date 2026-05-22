import pytest
from appium.webdriver.webdriver import WebDriver
from util.button import reset_item
from util.config import read_config
from util.enum import get_enum_value, select_enum_option
from util.message import ASSUMPTION_OUTDATED, CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, open_addon_config

ADDON_ID = "chttrans"


@pytest.mark.parametrize(
    "enum_id, initial_value, initial_config_value, target_value, target_config_value",
    [
        # static enum
        ("Engine", "OpenCC", "OpenCC", "Native", "Native"),
        # dynamic enum
        ("OpenCCS2TProfile", "Default", "default", "s2t.json", "s2t.json"),
    ],
)
def test_enum_selection(
    driver: WebDriver,
    app: str,
    enum_id: str,
    initial_value: str,
    initial_config_value: str,
    target_value: str,
    target_config_value: str,
):
    open_addon_config(driver, ADDON_ID)

    def read_config_value() -> str:
        cfg = read_config(app, "conf/chttrans.conf")
        return cfg["Global"][enum_id]

    picker = find_element_by_id(driver, enum_id)
    assert get_enum_value(picker) == initial_value, ASSUMPTION_OUTDATED

    select_enum_option(driver, picker, target_value)
    assert get_enum_value(picker) == target_value, UI_NOT_UPDATED
    assert read_config_value() == target_config_value, CHANGE_NOT_SAVED

    # Test Reset Item
    reset_item(picker)
    assert get_enum_value(picker) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_config_value, CHANGE_NOT_SAVED
