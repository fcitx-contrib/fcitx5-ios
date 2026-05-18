from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.remote.webelement import WebElement


def reset_item(item: WebElement) -> None:
    """Reset an item from its context menu."""
    item.parent.execute_script(
        "mobile: touchAndHold",
        {
            "elementId": item.id,
            "duration": 1.0,
        },
    )
    item.parent.find_element(AppiumBy.ACCESSIBILITY_ID, "Reset").click()
