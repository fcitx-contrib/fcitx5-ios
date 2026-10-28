from appium.webdriver.webdriver import WebDriver
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
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

    def is_focused() -> bool:
        try:
            return driver.switch_to.active_element == text_field
        except NoSuchElementException:
            return False

    # Test Stepper
    increment_stepper(driver, stepper_id)
    assert get_integer_value(text_field) == initial_value + 1, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value + 1), CHANGE_NOT_SAVED

    decrement_stepper(driver, stepper_id)
    assert get_integer_value(text_field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED
    assert not is_focused(), "Stepper unexpectedly focused the text field"

    # Focusing selects all digits, so typing replaces the value without clearing.
    # Repeat after submitting to verify selection also works when refocusing.
    for new_value in (10, 3):
        set_integer_value(text_field, new_value)
        assert get_integer_value(text_field) == new_value, UI_NOT_UPDATED
        assert read_config_value() == str(new_value), CHANGE_NOT_SAVED

    # The label and the gap immediately before the number also focus the field.
    label = find_element_by_id(driver, f"{DEFAULT_PAGE_SIZE}_label")
    label.click()
    WebDriverWait(driver, 10).until(lambda _: is_focused())
    text_field = find_element_by_id(driver, DEFAULT_PAGE_SIZE)
    text_field.send_keys("4\n")
    assert get_integer_value(text_field) == 4, UI_NOT_UPDATED
    assert read_config_value() == "4", CHANGE_NOT_SAVED

    for x, y, new_value in (
        (-4, text_field.rect["height"] / 2, 6),
        (text_field.rect["width"] / 2, text_field.rect["height"] / 2 - 21, 7),
    ):
        driver.execute_script(
            "mobile: tap", {"elementId": text_field.id, "x": x, "y": y}
        )
        WebDriverWait(driver, 10).until(lambda _: is_focused())
        text_field = find_element_by_id(driver, DEFAULT_PAGE_SIZE)
        text_field.send_keys(f"{new_value}\n")
        assert get_integer_value(text_field) == new_value, UI_NOT_UPDATED
        assert read_config_value() == str(new_value), CHANGE_NOT_SAVED

    # Test Reset Item
    label = find_element_by_id(driver, f"{DEFAULT_PAGE_SIZE}_label")
    reset_item(label)
    assert get_integer_value(text_field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED
