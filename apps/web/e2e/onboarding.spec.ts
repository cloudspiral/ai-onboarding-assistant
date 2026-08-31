import { expect, test } from "@playwright/test";

test("starts the Harbor onboarding flow with an anonymous persisted session", async ({ page }) => {
  test.skip(Boolean(process.env.LIVE_BASE_URL), "Local contract test uses a mocked API.");

  await page.route("http://localhost:3001/api/onboarding", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ onboarding: { step: "chat", status: "in_progress", stress_mode: "neutral", calm_mode_active: false, assessment: {}, details: null, booking: null } }),
    });
  });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Let’s get you set up" })).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Onboarding progress" })).toContainText("Your details");
  await expect(page.getByPlaceholder("Type your name…")).toBeEditable();
  await expect(page.getByText("Private & encrypted")).toBeVisible();
});

test("automatically enters a persistent gentle pace when elevated stress is detected", async ({ page }) => {
  test.skip(Boolean(process.env.LIVE_BASE_URL), "Local contract test uses a mocked API.");

  await page.route("http://localhost:3001/api/onboarding", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ onboarding: { step: "chat", status: "in_progress", stress_mode: "neutral", calm_mode_active: false, assessment: {}, details: null, booking: null } }),
  }));
  let chatCalls = 0;
  await page.route("http://localhost:3001/api/onboarding/chat", async (route) => {
    chatCalls += 1;
    const expected = chatCalls === 1
      ? { message: "I need a moment", field: "name" }
      : { message: "I’d like to skip this question.", field: "name", skip: true };
    expect(route.request().postDataJSON()).toEqual(expected);
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ turn: chatCalls === 1
        ? { intent: "express_distress", stress: "elevated", level: "elevated", assistant_reply: "Thank you for telling me. We can take one small step, pause, or skip.", calm_mode_active: true }
        : { intent: "skip_question", stress: "elevated", level: "elevated", assistant_reply: "That’s okay. We’ll leave this for a specialist and move to the next small step.", assessment_value: "Complete with specialist", calm_mode_active: true } }),
    });
  });

  await page.goto("/");
  await page.getByPlaceholder("Type your name…").fill("I need a moment");
  await page.getByRole("button", { name: "Send" }).click();

  await expect(page.getByText("Gentle pace is on")).toBeVisible();
  await expect(page.getByRole("button", { name: "Skip this question" })).toBeVisible();
  await expect(page.getByPlaceholder("Type your name…")).toBeEditable();
  await expect(page.getByText("Keep the gentler, one-step-at-a-time pace")).toHaveCount(0);

  await page.getByRole("button", { name: "Skip this question" }).click();
  await expect(page.getByText("What brings you to Harbor today?")).toBeVisible();
  await expect(page.getByText(/Noted — I’d like to skip/)).toHaveCount(0);
});
