from appium.webdriver.webdriver import WebDriver
from util.boolean import click_switch, get_switch_state
from util.button import reset_item
from util.config import read_global_config
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, open_global_config, reset_page

ACTIVE_BY_DEFAULT = "ActiveByDefault"
PREEDIT_ENABLED_BY_DEFAULT = "PreeditEnabledByDefault"


def test_toggles(driver: WebDriver, app: str) -> None:
    open_global_config(driver)

    def read_config_value(key: str) -> str:
        cfg = read_global_config(app)
        return cfg["Behavior"][key]

    active = find_element_by_id(driver, ACTIVE_BY_DEFAULT)
    preedit_enabled = find_element_by_id(driver, PREEDIT_ENABLED_BY_DEFAULT)
    active_on = get_switch_state(active)
    preedit_enabled_on = get_switch_state(preedit_enabled)

    click_switch(active)
    click_switch(preedit_enabled)
    assert get_switch_state(active) != active_on, UI_NOT_UPDATED
    assert get_switch_state(preedit_enabled) != preedit_enabled_on, UI_NOT_UPDATED
    assert read_config_value(ACTIVE_BY_DEFAULT) == str(not active_on), CHANGE_NOT_SAVED
    assert read_config_value(PREEDIT_ENABLED_BY_DEFAULT) == str(
        not preedit_enabled_on
    ), CHANGE_NOT_SAVED

    reset_item(active)
    assert get_switch_state(active) == active_on, UI_NOT_UPDATED
    assert get_switch_state(preedit_enabled) != preedit_enabled_on, UI_NOT_UPDATED
    assert read_config_value(ACTIVE_BY_DEFAULT) == str(active_on), CHANGE_NOT_SAVED
    assert read_config_value(PREEDIT_ENABLED_BY_DEFAULT) == str(
        not preedit_enabled_on
    ), CHANGE_NOT_SAVED

    click_switch(active)
    assert get_switch_state(active) != active_on, UI_NOT_UPDATED
    assert read_config_value(ACTIVE_BY_DEFAULT) == str(not active_on), CHANGE_NOT_SAVED

    reset_page(driver)
    assert get_switch_state(active) == active_on, UI_NOT_UPDATED
    assert get_switch_state(preedit_enabled) == preedit_enabled_on, UI_NOT_UPDATED
    assert read_config_value(ACTIVE_BY_DEFAULT) == str(active_on), CHANGE_NOT_SAVED
    assert read_config_value(PREEDIT_ENABLED_BY_DEFAULT) == str(preedit_enabled_on), (
        CHANGE_NOT_SAVED
    )
