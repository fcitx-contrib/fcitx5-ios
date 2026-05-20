from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement

from .screen import find_element_by_id


def get_enum_value(picker: WebElement) -> str:
    """Get the current selected value of a picker."""
    label = picker.get_attribute("label")
    return label.split(", ")[-1]


def select_enum_option(driver: WebDriver, picker: WebElement, option_value: str):
    """Click a picker and select an option by its value/identifier."""
    picker.click()
    find_element_by_id(driver, option_value).click()
