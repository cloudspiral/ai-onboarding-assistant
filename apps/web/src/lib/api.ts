import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const API_ORIGIN = process.env.NEXT_PUBLIC_API_ORIGIN ?? "http://localhost:3001";
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let supabase: SupabaseClient | null = null;
if (supabaseUrl && supabaseKey) supabase = createClient(supabaseUrl, supabaseKey);

export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public retryable = false,
    public status = 500,
  ) {
    super(message);
  }
}

async function authHeaders(): Promise<Record<string, string>> {
  if (supabase) {
    let { data } = await supabase.auth.getSession();
    if (!data.session) {
      const signedIn = await supabase.auth.signInAnonymously();
      if (signedIn.error) throw new ApiError("auth_failed", "We couldn’t start a private session. Please try again.");
      data = { session: signedIn.data.session };
    }
    return { Authorization: `Bearer ${data.session?.access_token}` };
  }

  let id = localStorage.getItem("harbor-demo-user");
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem("harbor-demo-user", id);
  }
  return { "X-Demo-User-Id": id };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = await authHeaders();
  const response = await fetch(`${API_ORIGIN}${path}`, {
    ...init,
    headers: {
      ...headers,
      ...(init.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
      ...init.headers,
    },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = payload.error ?? {};
    throw new ApiError(error.code ?? "request_failed", error.message ?? "Something went wrong. Please try again.", error.retryable, response.status);
  }
  return payload as T;
}

export type Onboarding = {
  step: "chat" | "details" | "booking" | "done";
  status: string;
  stress_mode: "neutral" | "elevated";
  calm_mode_opt_in: boolean;
  assessment: Record<string, string>;
  details: Details | null;
  booking: Booking | null;
};

export type Details = {
  full_name: string;
  date_of_birth: string;
  address: string;
  field_sources: Record<string, "ocr" | "missing" | "manual">;
  confirmed: boolean;
};

export type Booking = { reference: string; starts_at: string; channel: string; email_sent: boolean };
export type Slot = { id: number; starts_at: string; available: boolean };
export type Turn = { intent?: string; stress?: "neutral" | "elevated"; level: "neutral" | "elevated" | "urgent"; assistant_reply: string; next_actions?: string[] };

export const api = {
  getOnboarding: () => request<{ onboarding: Onboarding }>("/api/onboarding"),
  consent: (granted: boolean) => request<{ consent: string }>("/api/onboarding/consent", { method: "POST", body: JSON.stringify({ granted }) }),
  chat: (message: string, field?: string, calmModeOptIn = false) => request<{ turn: Turn }>("/api/onboarding/chat", { method: "POST", body: JSON.stringify({ message, field, calm_mode_opt_in: calmModeOptIn }) }),
  upload: (document: File) => {
    const body = new FormData();
    body.append("document", document);
    return request<{ fields: Record<string, string | null>; field_sources: Details["field_sources"]; raw_document_retained: false }>("/api/onboarding/document", { method: "POST", body });
  },
  saveDetails: (details: Omit<Details, "confirmed" | "field_sources">, fieldSources: Details["field_sources"]) => request<{ details: Details; source_photo_deleted: boolean }>("/api/onboarding/details", { method: "PATCH", body: JSON.stringify({ details, field_sources: fieldSources }) }),
  slots: () => request<{ slots: Slot[] }>("/api/appointment_slots"),
  book: (appointmentSlotId: number) => request<{ booking: Booking }>("/api/booking", { method: "POST", body: JSON.stringify({ appointment_slot_id: appointmentSlotId }) }),
  cancelBooking: () => request<{ booking: null }>("/api/booking", { method: "DELETE" }),
  complete: () => request<{ onboarding: Onboarding }>("/api/onboarding/complete", { method: "POST", body: "{}" }),
  deleteData: () => request<{ deleted: true }>("/api/onboarding", { method: "DELETE" }),
  adminAnalytics: () => request<{ totals: Record<string, number>; funnel: Record<string, number>; events: Record<string, number>; step_duration_ms: Record<string, number>; ocr: Record<string, number>; contains_pii: false }>("/api/admin/analytics", { headers: { "X-Demo-Role": "admin" } }),
  signIn: async (email: string, password: string) => {
    if (!supabase) throw new ApiError("auth_not_configured", "Admin sign-in is available in the deployed app.");
    const result = await supabase.auth.signInWithPassword({ email, password });
    if (result.error) throw new ApiError("invalid_credentials", "The email or password is incorrect.", false, 401);
    return result.data.session;
  },
};
