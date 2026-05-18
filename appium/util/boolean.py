from selenium.webdriver.remote.webelement import WebElement


def get_switch_state(switch: WebElement) -> bool:
    """Get the current state of a switch. True if ON, False if OFF."""
    return switch.get_attribute("value") == "1"


def click_switch(switch: WebElement) -> None:
    """Click the switch control."""
    rect = switch.rect
    switch.parent.execute_script(
        "mobile: tap",
        {
            "x": rect["x"] + rect["width"] - 30,
            "y": rect["y"] + rect["height"] / 2,
        },
    )
