import re

with open('/home/jules/verification/verify_test.py', 'w') as f:
    f.write('''from playwright.sync_api import sync_playwright

def run_cuj(page):
    page.goto("http://localhost:3000")

    # Wait for the splash screen to disappear and the main content to load
    # Based on the screenshot, wait for 'CoRide' logo text or the 'Create a Ride' button
    page.wait_for_selector('text="CoRide"', timeout=60000)
    page.wait_for_timeout(2000)

    # Click anything to wake it up
    page.mouse.click(10, 10)
    page.wait_for_timeout(2000)

    # Take screenshot at the key moment
    page.screenshot(path="/home/jules/verification/screenshots/verification_dashboard.png")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="/home/jules/verification/videos",
            viewport={'width': 1280, 'height': 800}
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()  # MUST close context to save the video
            browser.close()
''')
