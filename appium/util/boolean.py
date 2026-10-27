from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.support.ui import WebDriverWait


def get_switch_state(switch: WebElement) -> bool:
    """Get the current state of a switch. True if ON, False if OFF."""
    return switch.get_attribute("value") == "1"


def click_switch(switch: WebElement) -> None:
    """Click the switch control."""
    previous_rect = None

    def is_stationary(_):
        nonlocal previous_rect
        rect = switch.rect
        stationary = rect == previous_rect
        previous_rect = rect
        return stationary

    # A tap during scroll deceleration can just stop scrolling without toggling.
    WebDriverWait(switch.parent, 10, poll_frequency=0.2).until(is_stationary)
    rect = switch.rect
    switch.parent.execute_script(
        "mobile: tap",
        {
            "elementId": switch.id,
            "x": rect["width"] - 30,
            "y": rect["height"] / 2,
        },
    )
