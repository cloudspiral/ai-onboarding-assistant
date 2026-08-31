import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import axe from "axe-core";
import { beforeEach, describe, expect, it, vi } from "vitest";
import Home from "./page";

const mocks = vi.hoisted(() => ({
  getOnboarding: vi.fn(),
  chat: vi.fn(),
}));

vi.mock("@/lib/api", () => ({
  ApiError: class ApiError extends Error {
    constructor(public code: string, message: string, public retryable = false) { super(message); }
  },
  api: {
    getOnboarding: mocks.getOnboarding,
    chat: mocks.chat,
    consent: vi.fn(), upload: vi.fn(), saveDetails: vi.fn(), slots: vi.fn(),
    book: vi.fn(), cancelBooking: vi.fn(), complete: vi.fn(), deleteData: vi.fn(),
  },
}));

describe("Harbor onboarding", () => {
  beforeEach(() => {
    mocks.getOnboarding.mockResolvedValue({ onboarding: { step: "chat", status: "in_progress", stress_mode: "neutral", calm_mode_active: false, assessment: {}, details: null, booking: null } });
    mocks.chat.mockResolvedValue({ turn: { intent: "provide_details", stress: "neutral", level: "neutral", assistant_reply: "Thanks", calm_mode_active: false } });
  });

  it("renders an accessible first step with clear progress and input labeling", async () => {
    const { container } = render(<Home />);
    expect(await screen.findByRole("heading", { name: "Let’s get you set up" })).toBeInTheDocument();
    expect(screen.getByText("To start, what should we call you?")).toBeInTheDocument();
    expect(screen.getByRole("complementary", { name: "Onboarding progress" })).toHaveTextContent("About you");
    const results = await axe.run(container, { rules: { "color-contrast": { enabled: false } } });
    expect(results.violations).toEqual([]);
  });

  it("advances one question after a structured assistant response", async () => {
    render(<Home />);
    const user = userEvent.setup();
    await user.type(await screen.findByPlaceholderText("Type your name…"), "Avery");
    await user.click(screen.getByRole("button", { name: "Send" }));
    await waitFor(() => expect(screen.getByText(/What brings you to Harbor today\?/)).toBeInTheDocument(), { timeout: 2_000 });
    expect(mocks.chat).toHaveBeenCalledWith("Avery", "name", false);
  });

  it("automatically activates gentle pacing when the assistant detects elevated stress", async () => {
    mocks.chat
      .mockResolvedValueOnce({ turn: { intent: "express_distress", stress: "elevated", level: "elevated", assistant_reply: "Thank you for telling me. We can take one small step, pause, or skip.", calm_mode_active: true } })
      .mockRejectedValueOnce(new Error("temporary network failure"))
      .mockResolvedValueOnce({ turn: { intent: "skip_question", stress: "elevated", level: "elevated", assistant_reply: "That’s okay. We’ll leave this for a specialist and move to the next small step.", assessment_value: "Complete with specialist", calm_mode_active: true } });
    render(<Home />);
    const user = userEvent.setup();
    await user.type(await screen.findByPlaceholderText("Type your name…"), "I need a moment");
    await user.click(screen.getByRole("button", { name: "Send" }));

    expect(await screen.findByText("Gentle pace is on")).toBeInTheDocument();
    expect(screen.getByText(/We can take one small step, pause, or skip/)).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Type your name…")).not.toBeDisabled();
    expect(screen.getByRole("button", { name: "Skip this question" })).toBeInTheDocument();
    expect(screen.queryByText("Keep the gentler, one-step-at-a-time pace")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Skip this question" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Assistant unavailable");
    await user.click(screen.getByRole("button", { name: "Retry" }));
    await waitFor(() => expect(screen.getByText(/What brings you to Harbor today\?/)).toBeInTheDocument(), { timeout: 2_000 });
    expect(mocks.chat).toHaveBeenLastCalledWith("I’d like to skip this question.", "name", true);
    expect(screen.queryByText(/Noted — I’d like to skip/)).not.toBeInTheDocument();
  });

  it("shows retry and manual continuation when the provider fails", async () => {
    mocks.chat.mockRejectedValueOnce(new Error("provider down"));
    render(<Home />);
    const user = userEvent.setup();
    await user.type(await screen.findByPlaceholderText("Type your name…"), "Sample");
    await user.click(screen.getByRole("button", { name: "Send" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Assistant unavailable");
    expect(screen.getByRole("button", { name: "Retry" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Continue with the form" })).toBeInTheDocument();
  });
});
