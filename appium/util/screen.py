from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement


def find_elements_by_id(driver: WebDriver, identifier: str) -> list[WebElement]:
    """Find elements by their accessibility identifier."""
    elements = driver.find_elements(AppiumBy.ACCESSIBILITY_ID, identifier)
    actionable = [
        element
        for element in elements
        if element.tag_name not in ("XCUIElementTypeStaticText", "XCUIElementTypeOther")
    ]
    return actionable or elements


def find_element_by_id(driver: WebDriver, identifier: str) -> WebElement:
    """Find an element by its accessibility identifier."""
    elements = find_elements_by_id(driver, identifier)
    if len(elements) != 1:
        raise ValueError(f"{len(elements)} elements match identifier {identifier}")
    return elements[0]


def open_global_config(driver: WebDriver):
    """Open the Global Config screen."""
    find_element_by_id(driver, "Global Config").click()


def open_addon_config(driver: WebDriver):
    """Open the Addon Config screen."""
    find_element_by_id(driver, "Addon Config").click()


def reset_page(driver: WebDriver):
    find_element_by_id(driver, "ResetPage").click()
