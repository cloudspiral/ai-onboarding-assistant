import { expect, test } from "@playwright/test";

test.skip(Boolean(process.env.LIVE_BASE_URL), "Local failure-path tests use a mocked API.");

const onboarding = (step: "chat" | "details" = "chat") => ({
  onboarding: {
    step,
    status: "in_progress",
    stress_mode: "neutral",
    calm_mode_active: false,
    assessment: {},
    details: null,
    booking: null,
  },
});

test("offers retry and manual continuation when the LLM is unavailable", async ({ page }) => {
  await page.route("http://localhost:3001/api/onboarding", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(onboarding()) }));
  await page.route("http://localhost:3001/api/onboarding/chat", (route) => route.fulfill({
    status: 503,
    contentType: "application/json",
    body: JSON.stringify({ error: { code: "timeout", message: "The assistant is temporarily unavailable.", retryable: true } }),
  }));

  await page.goto("/");
  await page.getByPlaceholder("Type your name…").fill("SYNTHETIC FAILURE USER");
  await page.getByRole("button", { name: "Send" }).click();

  const alert = page.getByRole("alert").filter({ hasText: "Assistant unavailable" });
  await expect(alert).toContainText("Assistant unavailable");
  await expect(alert.getByRole("button", { name: "Retry" })).toBeVisible();
  await alert.getByRole("button", { name: "Continue with the form" }).click();
  await expect(page.getByRole("heading", { name: "Before you share a document" })).toBeVisible();
});

test("turns an OCR failure into a manual-entry path", async ({ page }) => {
  await page.route("http://localhost:3001/api/onboarding", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(onboarding("details")) }));
  await page.route("http://localhost:3001/api/onboarding/consent", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ consent: "granted" }) }));
  await page.route("http://localhost:3001/api/onboarding/document", (route) => route.fulfill({
    status: 422,
    contentType: "application/json",
    body: JSON.stringify({ error: { code: "ocr_failed", message: "We couldn’t read that photo.", retryable: false } }),
  }));

  await page.goto("/");
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByRole("button", { name: "Use sample photo" }).click();

  await expect(page.getByRole("heading", { name: "We couldn’t read that photo" })).toBeVisible();
  await page.getByRole("button", { name: "Type details instead" }).click();
  await expect(page.getByLabel("Full legal name")).toBeEditable();
  await expect(page.getByLabel("Date of birth")).toBeEditable();
  await expect(page.getByLabel("Home address")).toBeEditable();
});

test("preserves partial OCR fields and clearly marks the missing field", async ({ page }) => {
  await page.route("http://localhost:3001/api/onboarding", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(onboarding("details")) }));
  await page.route("http://localhost:3001/api/onboarding/consent", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ consent: "granted" }) }));
  await page.route("http://localhost:3001/api/onboarding/document", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({
      fields: { full_name: "SYNTHETIC PARTIAL USER", date_of_birth: "1990-01-01", address: null },
      field_sources: { full_name: "ocr", date_of_birth: "ocr", address: "missing" },
      raw_document_retained: false,
    }),
  }));

  await page.goto("/");
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByRole("button", { name: "Use sample photo" }).click();

  await expect(page.getByRole("heading", { name: "Confirm your details" })).toBeVisible();
  await expect(page.getByLabel("Full legal name")).toHaveValue("SYNTHETIC PARTIAL USER");
  await expect(page.getByLabel("Date of birth")).toHaveValue("1990-01-01");
  await expect(page.getByLabel("Home address")).toHaveValue("");
  await expect(page.getByText("Couldn’t read — please add")).toBeVisible();
  await expect(page.getByRole("button", { name: "These are correct" })).toBeDisabled();
});
