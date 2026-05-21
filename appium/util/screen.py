from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def find_elements_by_id(driver: WebDriver, identifier: str) -> list[WebElement]:
    """Find elements by their accessibility identifier."""
    elements = driver.find_elements(AppiumBy.ACCESSIBILITY_ID, identifier)
    # Filter for actionable elements (not just static text/containers)
    actionable = [
        element
        for element in elements
        if element.tag_name not in ("XCUIElementTypeStaticText", "XCUIElementTypeOther")
    ]
    return actionable or elements


def find_element_by_id(
    driver: WebDriver, identifier: str, timeout: float = 10.0
) -> WebElement:
    """Find an element by its accessibility identifier with explicit wait."""
    wait = WebDriverWait(driver, timeout)
    try:
        # Wait until at least one element with this ID is present
        wait.until(
            EC.presence_of_element_located((AppiumBy.ACCESSIBILITY_ID, identifier))
        )
        # Use our filtering logic to pick the best candidate
        elements = find_elements_by_id(driver, identifier)
        return elements[0]
    except Exception:
        raise ValueError(f"Timeout after {timeout}s: element {identifier} not found")


def open_global_config(driver: WebDriver):
    """Open the Global Config screen."""
    find_element_by_id(driver, "Global Config").click()


def open_addon_config(driver: WebDriver):
    """Open the Addon Config screen."""
    find_element_by_id(driver, "Addon Config").click()


def reset_page(driver: WebDriver):
    find_element_by_id(driver, "ResetPage").click()


def back(driver: WebDriver):
    """Click the Back button."""
    find_element_by_id(driver, "BackButton").click()


def scroll_to_id(
    driver: WebDriver, identifier: str, timeout: float = 10.0
) -> WebElement:
    while True:
        try:
            elements = find_elements_by_id(driver, identifier)
            if elements and elements[0].is_displayed():
                return elements[0]
        except Exception:
            pass
        driver.execute_script("mobile: swipe", {"direction": "up"})
