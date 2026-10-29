from appium.webdriver.webdriver import WebDriver
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
from util.button import reset_item
from util.config import read_config, read_global_config
from util.integer import (
    decrement_stepper,
    get_integer_value,
    increment_stepper,
    set_integer_value,
)
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.screen import find_element_by_id, open_global_config

DEFAULT_PAGE_SIZE = "DefaultPageSize"
SUGGESTION_TIMEOUT = "SuggestionTimeout"
HISTORY_LIMIT = "HistoryLimit"


def test_clipboard_integer_bounds(driver: WebDriver, app: str):
    # SuggestionTimeout has only a lower bound of -1. Constructing a bounded
    # Stepper with -1...Int.max used to overflow just by opening this page.
    find_element_by_id(driver, "Clipboard").click()
    timeout = find_element_by_id(driver, SUGGESTION_TIMEOUT)
    assert get_integer_value(timeout) == 30
    stepper_id = f"{SUGGESTION_TIMEOUT}_stepper"

    decrement_stepper(driver, stepper_id)
    assert get_integer_value(timeout) == 29, UI_NOT_UPDATED
    set_integer_value(timeout, -1)
    assert get_integer_value(timeout) == -1, UI_NOT_UPDATED
    assert (
        read_config(app, "conf/iosfrontend.conf")["Clipboard"][SUGGESTION_TIMEOUT]
        == "-1"
    )
    assert not find_element_by_id(driver, f"{stepper_id}-Decrement").is_enabled()

    increment_stepper(driver, stepper_id)
    assert get_integer_value(timeout) == 0, UI_NOT_UPDATED
    assert (
        read_config(app, "conf/iosfrontend.conf")["Clipboard"][SUGGESTION_TIMEOUT]
        == "0"
    )

    history = find_element_by_id(driver, HISTORY_LIMIT)
    history_stepper_id = f"{HISTORY_LIMIT}_stepper"
    set_integer_value(history, 0)
    assert not find_element_by_id(
        driver, f"{history_stepper_id}-Decrement"
    ).is_enabled()
    increment_stepper(driver, history_stepper_id)
    assert get_integer_value(history) == 1, UI_NOT_UPDATED


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
