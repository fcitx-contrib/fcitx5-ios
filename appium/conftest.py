import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime
from typing import Any, Generator

import pytest
from appium.options.ios import XCUITestOptions
from appium.webdriver.webdriver import WebDriver

from appium import webdriver

APPIUM_SERVER = "http://127.0.0.1:4723"
BUNDLE_ID = "org.fcitx.Fcitx5"
DEVICE_NAME = os.environ.get("FCITX5_IOS_DEVICE", "iPhone 17")
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def check_appium_server() -> bool:
    """Check if Appium server is running and ready."""
    try:
        with urllib.request.urlopen(f"{APPIUM_SERVER}/status", timeout=1) as resp:
            data = json.loads(resp.read())
            return data.get("value", {}).get("ready", False)
    except Exception:
        return False


def find_simulator_udid(device_name: str) -> str:
    """Return the UDID for the named available simulator."""
    output = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
    )
    devices_by_runtime: dict[str, list[dict[str, Any]]] = json.loads(output)["devices"]
    for devices in devices_by_runtime.values():
        for device in devices:
            if device.get("name") == device_name:
                return str(device["udid"])
    pytest.fail(f"Simulator {device_name!r} is not available")


@pytest.fixture(scope="session")
def appium_server() -> Generator[str, None, None]:
    """Start Appium server at session start and stop it at session end."""
    proc = subprocess.Popen(
        ["appium"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    # Wait for server to be ready (up to 5 seconds)
    for _ in range(5):
        if check_appium_server():
            break
        time.sleep(1)
    else:
        pytest.fail("Appium server did not start within 5 seconds")

    yield APPIUM_SERVER

    # Teardown: kill the Appium server
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


@pytest.fixture(scope="session")
def simulator_udid() -> str:
    """Return the target iPhone simulator UDID."""
    return find_simulator_udid(DEVICE_NAME)


@pytest.fixture(scope="session")
def session_base_dir() -> Generator[str, None, None]:
    """Create a unique base config directory for this test session."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    base_dir = os.path.join(project_root, "build/appium", timestamp)
    os.makedirs(base_dir, exist_ok=True)
    yield base_dir


@pytest.fixture(scope="session")
def driver(appium_server: str, simulator_udid: str) -> Generator[WebDriver, None, None]:
    """Create and teardown the Appium driver session."""
    options = XCUITestOptions()
    options.platform_name = "iOS"
    options.automation_name = "XCUITest"
    options.device_name = DEVICE_NAME
    options.set_capability("udid", simulator_udid)
    options.set_capability("bundleId", BUNDLE_ID)
    options.set_capability("autoLaunch", False)

    drv = webdriver.Remote(appium_server, options=options)
    yield drv
    drv.quit()


@pytest.fixture(scope="function")
def app(
    request: pytest.FixtureRequest,
    driver: WebDriver,
    session_base_dir: str,
) -> Generator[str, None, None]:
    """Keep Fcitx5 in foreground for a single test case."""
    config_home = os.path.join(session_base_dir, request.node.name, "config")
    os.makedirs(config_home)
    data_home = os.path.join(session_base_dir, request.node.name, "data")
    os.makedirs(data_home)

    driver.terminate_app(BUNDLE_ID)
    driver.execute_script(
        "mobile: launchApp",
        {
            "bundleId": BUNDLE_ID,
            "arguments": [],
            "environment": {
                "FCITX_CONFIG_HOME": config_home,
                "FCITX_DATA_HOME": data_home,
            },
        },
    )
    yield config_home
    driver.terminate_app(BUNDLE_ID)
