import { expect, test } from "@playwright/test";

test("starts the Harbor onboarding flow with an anonymous persisted session", async ({ page }) => {
  await page.route("http://localhost:3001/api/onboarding", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ onboarding: { step: "chat", status: "in_progress", stress_mode: "neutral", calm_mode_opt_in: false, assessment: {}, details: null, booking: null } }),
    });
  });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Let’s get you set up" })).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Onboarding progress" })).toContainText("Your details");
  await expect(page.getByPlaceholder("Type your name…")).toBeEditable();
  await expect(page.getByText("Private & encrypted")).toBeVisible();
});
