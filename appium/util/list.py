from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.actions import interaction
from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.pointer_input import PointerInput
from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def delete_item(driver: WebDriver, item: WebElement) -> None:
    """Delete an item from a list by swiping left and clicking Delete."""
    driver.execute_script(
        "mobile: swipe",
        {"direction": "left", "element": item.id, "velocity": 500},
    )
    delete_btn = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((AppiumBy.ACCESSIBILITY_ID, "Delete"))
    )
    delete_btn.click()


def move_item(driver: WebDriver, source: WebElement, target: WebElement) -> None:
    """Move an item by dragging it from source to target with a long press."""
    source_rect = source.rect
    target_rect = target.rect

    # Drag from the center of the source element.
    # Reordering typically requires a long press to trigger.
    start_x = source_rect["x"] + source_rect["width"] / 2
    start_y = source_rect["y"] + source_rect["height"] / 2

    # Move to the target. For reordering, moving to the top edge of the target
    # cell often works better to trigger the shift.
    end_x = target_rect["x"] + target_rect["width"] / 2
    end_y = target_rect["y"]

    actions = ActionChains(driver)
    actions.w3c_actions = ActionBuilder(
        driver, mouse=PointerInput(interaction.POINTER_TOUCH, "touch")
    )
    actions.w3c_actions.pointer_action.move_to_location(start_x, start_y)
    actions.w3c_actions.pointer_action.pointer_down()
    actions.w3c_actions.pointer_action.pause(1.5)
    actions.w3c_actions.pointer_action.move_to_location(end_x, end_y)
    actions.w3c_actions.pointer_action.release()
    actions.perform()
