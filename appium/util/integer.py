from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement

from .screen import find_element_by_id


def increment_stepper(driver: WebDriver, stepper_id: str):
    """Click the increment button on a stepper."""
    find_element_by_id(driver, f"{stepper_id}-Increment").click()


def decrement_stepper(driver: WebDriver, stepper_id: str):
    """Click the decrement button on a stepper."""
    find_element_by_id(driver, f"{stepper_id}-Decrement").click()


def set_integer_value(text_field: WebElement, value: int):
    """Set the value of an integer text field."""
    text_field.clear()
    text_field.send_keys(str(value))
    text_field.send_keys("\n")


def get_integer_value(text_field: WebElement) -> int:
    """Get the current value of an integer text field."""
    return int(text_field.get_attribute("value") or "0")
