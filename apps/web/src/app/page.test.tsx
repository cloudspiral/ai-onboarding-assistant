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
    mocks.getOnboarding.mockResolvedValue({ onboarding: { step: "chat", status: "in_progress", stress_mode: "neutral", calm_mode_opt_in: false, assessment: {}, details: null, booking: null } });
    mocks.chat.mockResolvedValue({ turn: { intent: "provide_details", stress: "neutral", level: "neutral", assistant_reply: "Thanks" } });
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
    await waitFor(() => expect(screen.getByText("What brings you to Harbor today?")).toBeInTheDocument(), { timeout: 2_000 });
    expect(mocks.chat).toHaveBeenCalledWith("Avery", "name", false);
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
