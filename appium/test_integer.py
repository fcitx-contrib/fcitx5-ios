from appium.webdriver.webdriver import WebDriver
from util.button import reset_item
from util.config import read_global_config
from util.integer import (
    decrement_stepper,
    get_integer_value,
    increment_stepper,
    set_integer_value,
)
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, open_global_config

DEFAULT_PAGE_SIZE = "DefaultPageSize"


def test_integer(driver: WebDriver, app: str):
    open_global_config(driver)

    def read_config_value() -> str:
        cfg = read_global_config(app)
        return cfg["Behavior"][DEFAULT_PAGE_SIZE]

    text_field = find_element_by_id(driver, DEFAULT_PAGE_SIZE)
    stepper_id = f"{DEFAULT_PAGE_SIZE}_stepper"
    initial_value = get_integer_value(text_field)

    # Test Stepper
    increment_stepper(driver, stepper_id)
    assert get_integer_value(text_field) == initial_value + 1, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value + 1), CHANGE_NOT_SAVED

    decrement_stepper(driver, stepper_id)
    assert get_integer_value(text_field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED

    # Test TextField
    new_value = initial_value + 5
    set_integer_value(text_field, new_value)
    assert get_integer_value(text_field) == new_value, UI_NOT_UPDATED
    assert read_config_value() == str(new_value), CHANGE_NOT_SAVED

    # Test Reset Item
    label = find_element_by_id(driver, f"{DEFAULT_PAGE_SIZE}_label")
    reset_item(label)
    assert get_integer_value(text_field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED
