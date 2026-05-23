import time

from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.config import read_config
from util.enum import get_enum_value, select_enum_option
from util.list import delete_item, move_item
from util.message import ASSUMPTION_OUTDATED, CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, find_elements_by_id, open_addon_config

PROVIDER_ORDER = "ProviderOrder"


def test_spell_backend_list(driver: WebDriver, app: str):
    open_addon_config(driver, "spell")
    time.sleep(0.5)  # If click happens before transition, it will have no effect.
    find_element_by_id(driver, PROVIDER_ORDER).click()

    def get_provider_values(items: list[WebElement]) -> list[str]:
        return [get_enum_value(item) for item in items]

    def read_config_value() -> dict[str, str]:
        return read_config(app, "conf/spell.conf")[PROVIDER_ORDER]

    items = []
    while len(items) != 3:
        items = find_elements_by_id(driver, PROVIDER_ORDER)

    assert get_provider_values(items) == ["Presage", "Custom", "Enchant"], (
        ASSUMPTION_OUTDATED
    )

    delete_item(driver, items[1])
    while len(items) != 2:
        items = find_elements_by_id(driver, PROVIDER_ORDER)

    assert get_provider_values(items) == ["Presage", "Enchant"], UI_NOT_UPDATED
    assert read_config_value() == {"0": "Presage", "1": "Enchant"}, UI_NOT_UPDATED

    # Click plus to add a new item
    find_element_by_id(driver, "plus").click()
    items = find_elements_by_id(driver, PROVIDER_ORDER)
    assert len(items) == 3, UI_NOT_UPDATED

    select_enum_option(driver, items[2], "Custom")
    items = find_elements_by_id(driver, PROVIDER_ORDER)
    assert get_provider_values(items) == ["Presage", "Enchant", "Custom"], (
        UI_NOT_UPDATED
    )
    assert read_config_value() == {"0": "Presage", "1": "Enchant", "2": "Custom"}, (
        CHANGE_NOT_SAVED
    )

    # Drag index 1 to the beginning
    move_item(driver, items[1], items[0])
    assert get_provider_values(find_elements_by_id(driver, PROVIDER_ORDER)) == [
        "Enchant",
        "Presage",
        "Custom",
    ], UI_NOT_UPDATED
    assert read_config_value() == {"0": "Enchant", "1": "Presage", "2": "Custom"}, (
        CHANGE_NOT_SAVED
    )

    find_element_by_id(driver, "ResetList").click()
    items = find_elements_by_id(driver, PROVIDER_ORDER)
    assert get_provider_values(items) == ["Presage", "Custom", "Enchant"], (
        UI_NOT_UPDATED
    )
    assert read_config_value() == {"0": "Presage", "1": "Custom", "2": "Enchant"}, (
        CHANGE_NOT_SAVED
    )
