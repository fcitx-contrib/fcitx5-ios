from appium.webdriver.webdriver import WebDriver
from util.boolean import click_switch, get_switch_state
from util.config import read_config
from util.message import (
    CHANGE_NOT_SAVED,
    CHANGE_WRONGLY_SAVED,
    UI_NOT_UPDATED,
    UI_WRONGLY_UPDATED,
)
from util.screen import back, find_element_by_id, scroll_to_id

FUZZY = "Fuzzy"
SWITCH_IDS = ["VAsQuickphrase", "VE_UE", "NG_GN"]


def test_reset_group(driver: WebDriver, app: str):
    find_element_by_id(driver, "pinyin").click()

    def read_config_values() -> list[str]:
        cfg = read_config(app, "conf/pinyin.conf")
        return [
            cfg["Global"][SWITCH_IDS[0]],
            cfg[FUZZY][SWITCH_IDS[1]],
            cfg[FUZZY][SWITCH_IDS[2]],
        ]

    fuzzy = scroll_to_id(driver, FUZZY)
    v_as_quickphrase = find_element_by_id(driver, SWITCH_IDS[0])
    initial_config = read_config_values()
    v_as_quickphrase_on = get_switch_state(v_as_quickphrase)
    click_switch(v_as_quickphrase)
    assert (
        get_switch_state(find_element_by_id(driver, SWITCH_IDS[0]))
        != v_as_quickphrase_on
    ), UI_NOT_UPDATED

    fuzzy.click()
    toggled_ui = []
    for toggle_id in SWITCH_IDS[1:]:
        toggle = find_element_by_id(driver, toggle_id)
        is_on = get_switch_state(toggle)
        click_switch(toggle)
        assert get_switch_state(toggle) != is_on, UI_NOT_UPDATED
        toggled_ui.append(not is_on)

    current_config = read_config_values()
    for i in range(3):
        assert current_config[i] != initial_config[i], CHANGE_NOT_SAVED

    find_element_by_id(driver, "ResetGroup").click()
    for i, toggle_id in enumerate(SWITCH_IDS[1:]):
        assert (
            get_switch_state(find_element_by_id(driver, toggle_id)) != toggled_ui[i]
        ), UI_NOT_UPDATED

    back(driver)
    assert (
        get_switch_state(find_element_by_id(driver, SWITCH_IDS[0]))
        != v_as_quickphrase_on
    ), UI_WRONGLY_UPDATED
    after_reset = read_config_values()
    assert after_reset[0] != initial_config[0], CHANGE_WRONGLY_SAVED
    assert after_reset[1] == initial_config[1], CHANGE_NOT_SAVED
    assert after_reset[2] == initial_config[2], CHANGE_NOT_SAVED
