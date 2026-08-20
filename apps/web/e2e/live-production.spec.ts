import { expect, test, type Page } from "@playwright/test";

test.skip(!process.env.LIVE_BASE_URL, "Set LIVE_BASE_URL to run production acceptance tests.");

const apiOrigin = process.env.LIVE_API_ORIGIN ?? "https://api-production-21140.up.railway.app";

async function browserAccessToken(page: Page) {
  return page.evaluate(() => {
    const find = (value: unknown): string | null => {
      if (!value || typeof value !== "object") return null;
      if ("access_token" in value && typeof value.access_token === "string") return value.access_token;
      for (const child of Object.values(value)) {
        const token = find(child);
        if (token) return token;
      }
      return null;
    };
    for (let index = 0; index < localStorage.length; index += 1) {
      const key = localStorage.key(index);
      if (!key?.startsWith("sb-")) continue;
      try {
        const token = find(JSON.parse(localStorage.getItem(key) ?? "null"));
        if (token) return token;
      } catch {
        // Ignore unrelated or partially written local storage entries.
      }
    }
    return null;
  });
}

test.afterEach(async ({ page, request }, testInfo) => {
  if (!testInfo.title.startsWith("completes and deletes")) return;
  const token = await browserAccessToken(page).catch(() => null);
  if (!token) return;
  await request.delete(`${apiOrigin}/api/onboarding`, { headers: { Authorization: `Bearer ${token}` } }).catch(() => undefined);
});

test("completes and deletes the full production onboarding journey", async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto("/");
  await page.getByPlaceholder("Type your name…").fill("SYNTHETIC BROWSER QA");
  await page.getByRole("button", { name: "Send" }).click();
  await page.getByRole("button", { name: "Registering for the first time" }).click();
  await page.getByRole("button", { name: "Within the next few weeks" }).click();
  await page.getByRole("button", { name: "Nothing right now" }).click();
  await page.getByRole("button", { name: "Continue to my details →" }).click();

  await page.getByRole("checkbox", { name: /I agree to Harbor processing/ }).check();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByRole("button", { name: "Use sample photo" }).click();
  await expect(page.getByRole("heading", { name: "Confirm your details" })).toBeVisible();
  await page.getByRole("button", { name: "These are correct" }).click();
  await expect(page.getByRole("heading", { name: "Details saved" })).toBeVisible();
  await page.getByRole("button", { name: "Continue to booking" }).click();

  const booking = page.locator('section[data-screen-label="Appointment booking"]');
  await booking.locator("button:not([disabled])").first().click();
  await page.getByRole("button", { name: "Confirm booking" }).click();
  await expect(page.getByRole("heading", { name: "You’re booked" })).toBeVisible();
  await page.getByRole("button", { name: "Finish up" }).click();
  await expect(page.getByRole("heading", { name: /You’re all set/ })).toBeVisible();

  await page.getByRole("button", { name: "Delete my data" }).click();
  await page.getByRole("button", { name: "Delete everything" }).click();
  await expect(page.getByRole("heading", { name: "Your data has been deleted" })).toBeVisible();
});

test("signs a pre-provisioned admin into the production aggregate dashboard", async ({ page }) => {
  const password = process.env.HARBOR_ADMIN_PASSWORD;
  test.skip(!password, "Set HARBOR_ADMIN_PASSWORD to verify staff login.");

  await page.goto("/admin");
  await page.getByLabel("Password").fill(password!);
  await page.getByRole("button", { name: "Sign in" }).click();

  await expect(page.getByText("PII present:")).toContainText("No");
  await expect(page.getByText("Sessions")).toBeVisible();
});
