"use client";

import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, ApiError, type Booking, type Details, type Slot, type Turn } from "@/lib/api";
import styles from "./page.module.css";

type Step = "chat" | "details" | "booking" | "done";
type DocPhase = "consent" | "upload" | "scanning" | "review" | "failed" | "saved";
type Message = { id: string; speaker: "assistant" | "user"; text: string };
type Support = { key: string; title: string; body: string };

const QUESTIONS = [
  "To start, what should we call you?",
  "What brings you to Harbor today?",
  "How soon would you like your first appointment?",
  "Last question — anything you’d like the team to keep in mind?",
] as const;
const FIELDS = ["name", "reason", "timing", "note"] as const;
const CHIPS: Record<number, string[]> = {
  1: ["Registering for the first time", "Transferring from another provider", "I’m not sure where to start"],
  2: ["As soon as possible", "Within the next few weeks", "Just exploring for now"],
  3: ["I’m feeling a bit overwhelmed", "Nothing right now"],
};
const SUPPORT: Record<string, Support> = {
  idle: { key: "idle", title: "No rush at all", body: "Take all the time you need — nothing here expires. If a question feels hard, you can skip it and a specialist will pick it up with you." },
  uncertain: { key: "uncertain", title: "You don’t need it all figured out", body: "Answer what you can — anything you skip can be finished later, and a specialist personally reviews every registration before your first visit." },
  elevated: { key: "elevated", title: "We’re with you", body: "Feeling overwhelmed at this stage is common. Everything from here is small steps, and a real person is behind each one." },
  ocr: { key: "ocr", title: "This step trips a lot of people", body: "A photo just saves typing — entering your details by hand takes about a minute and works exactly as well. Nothing about your registration is affected." },
};

const initialMessages: Message[] = [
  { id: "hello", speaker: "assistant", text: "Hi, I’m Wren — I’ll help you get set up with Harbor. It takes about ten minutes, and you can pause anytime." },
  { id: "start", speaker: "assistant", text: QUESTIONS[0] },
];

function message(speaker: Message["speaker"], text: string): Message {
  return { id: crypto.randomUUID(), speaker, text };
}

function acknowledgment(index: number, answer: string, stress?: Turn["level"]) {
  if (stress === "elevated") return "Thank you for telling me. We’ll take this at your pace — you can continue one small step, pause, or skip this for a specialist.";
  if (index === 0) return `Nice to meet you, ${answer}.`;
  if (answer === "Registering for the first time") return "Welcome — we’re glad you found us.";
  if (answer === "Transferring from another provider") return "Got it — we’ll make the handover as smooth as we can.";
  if (answer === "I’m not sure where to start") return "That’s completely fine — plenty of people start here without a plan. We’ll figure it out together.";
  if (answer === "As soon as possible") return "We’ll prioritize the earliest openings for you.";
  if (answer === "Within the next few weeks") return "Plenty of time — you’ll see a range of openings.";
  if (answer === "Just exploring for now") return "No pressure at all.";
  return "Noted — thank you.";
}

export default function Home() {
  const [step, setStep] = useState<Step>("chat");
  const [assessment, setAssessment] = useState<Record<string, string>>({});
  const [details, setDetails] = useState<Details | null>(null);
  const [booking, setBooking] = useState<Booking | null>(null);
  const [calmModeActive, setCalmModeActive] = useState(false);
  const [support, setSupport] = useState<Support | null>(null);
  const [, setSeenSupport] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [deleted, setDeleted] = useState(false);

  const showSupport = useCallback((kind: keyof typeof SUPPORT) => {
    setSeenSupport((seen) => {
      if (seen.has(kind)) return seen;
      setSupport(SUPPORT[kind]);
      return new Set(seen).add(kind);
    });
  }, []);

  useEffect(() => {
    api.getOnboarding()
      .then(({ onboarding }) => {
        setStep(onboarding.step);
        setAssessment(onboarding.assessment ?? {});
        setDetails(onboarding.details);
        setBooking(onboarding.booking);
        setCalmModeActive(onboarding.calm_mode_active);
      })
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!support) return;
    const timer = window.setTimeout(() => setSupport(null), 10_000);
    return () => window.clearTimeout(timer);
  }, [support]);

  const finishDetails = (value: Details) => { setDetails(value); setStep("booking"); };
  const finishBooking = async (value: Booking) => { setBooking(value); const { onboarding } = await api.complete(); setStep(onboarding.step); };
  const deleteEverything = async () => { await api.deleteData(); setDeleted(true); setAssessment({}); setDetails(null); setBooking(null); };
  const startOver = () => { localStorage.removeItem("harbor-demo-user"); location.reload(); };

  if (loading) return <div className={styles.loading}>Preparing your private session…</div>;

  return (
    <div className={styles.shell}>
      <header className={styles.header}><div className={styles.brand}><span>Harbor</span><small>Specialized services onboarding</small></div><div className={styles.private}><i />Private &amp; encrypted</div></header>
      <div className={styles.workspace}>
        <StepRail step={step} />
        <main className={styles.main}>
          {deleted ? <Deleted onStartOver={startOver} /> : <>
            {step === "chat" && <Chat assessment={assessment} setAssessment={setAssessment} initialCalmModeActive={calmModeActive} onContinue={() => setStep("details")} showSupport={showSupport} />}
            {step === "details" && <DocumentStep existing={details} onSaved={finishDetails} showSupport={showSupport} />}
            {step === "booking" && <BookingStep current={booking} onBooked={finishBooking} />}
            {step === "done" && details && booking && <Done assessment={assessment} details={details} booking={booking} onDelete={deleteEverything} />}
          </>}
        </main>
      </div>
      {support && <SupportCard support={support} onDismiss={() => setSupport(null)} />}
    </div>
  );
}

function StepRail({ step }: { step: Step }) {
  const items: { step: Step; title: string; sub: string }[] = [
    { step: "chat", title: "About you", sub: "Guided chat" }, { step: "details", title: "Your details", sub: "Photo or typed" },
    { step: "booking", title: "Book a visit", sub: "Pick a time" }, { step: "done", title: "All set", sub: "Review & finish" },
  ];
  const active = items.findIndex((item) => item.step === step);
  return <aside className={styles.rail} aria-label="Onboarding progress"><ol>{items.map((item, index) => {
    const state = index < active ? "done" : index === active ? "current" : "upcoming";
    return <li key={item.step} className={styles[state]} aria-current={state === "current" ? "step" : undefined}><span className={styles.stepNumber}>{state === "done" ? "✓" : index + 1}</span><span><b>{item.title}</b><small>{item.sub}</small></span></li>;
  })}</ol><div className={styles.railFooter}>Your answers stay private.<br /><a href="/privacy">How we handle your data</a></div></aside>;
}

function Chat({ assessment, setAssessment, initialCalmModeActive, onContinue, showSupport }: { assessment: Record<string, string>; setAssessment: (value: Record<string, string>) => void; initialCalmModeActive: boolean; onContinue: () => void; showSupport: (kind: keyof typeof SUPPORT) => void }) {
  const completed = FIELDS.filter((field) => assessment[field]).length;
  const [qIndex, setQIndex] = useState(Math.min(completed, 4));
  const [messages, setMessages] = useState<Message[]>(() => completed ? [...initialMessages, message("assistant", "Welcome back. Your earlier answers are saved — we can continue where you left off."), ...(completed < 4 ? [message("assistant", QUESTIONS[completed])] : [])] : initialMessages);
  const [draft, setDraft] = useState("");
  const [typing, setTyping] = useState(false);
  const [providerError, setProviderError] = useState<ApiError | null>(null);
  const [lastAttempt, setLastAttempt] = useState<{ answer: string; skip: boolean } | null>(null);
  const [calmModeActive, setCalmModeActive] = useState(initialCalmModeActive);
  const transcript = useRef<HTMLDivElement>(null);

  useEffect(() => { if (transcript.current) transcript.current.scrollTop = transcript.current.scrollHeight; }, [messages, typing, providerError]);
  useEffect(() => { if (qIndex >= 4 || typing) return; const timer = window.setTimeout(() => showSupport("idle"), 30_000); return () => window.clearTimeout(timer); }, [qIndex, typing, showSupport]);

  const submit = async (answer: string, skip = false) => {
    const displayedAnswer = skip ? "I’d like to skip this question." : answer.trim();
    if (!displayedAnswer || typing || qIndex >= 4) return;
    setLastAttempt({ answer: displayedAnswer, skip });
    setProviderError(null); setDraft(""); setMessages((current) => [...current, message("user", displayedAnswer)]); setTyping(true);
    if (displayedAnswer === "I’m not sure where to start") showSupport("uncertain");
    try {
      const { turn } = await api.chat(displayedAnswer, FIELDS[qIndex], skip);
      await new Promise((resolve) => window.setTimeout(resolve, 500));
      if (turn.calm_mode_active && !calmModeActive) { setCalmModeActive(true); showSupport("elevated"); }
      if (turn.level === "urgent") { setMessages((current) => [...current, message("assistant", turn.assistant_reply)]); return; }
      if (turn.intent === "express_distress") { setMessages((current) => [...current, message("assistant", turn.assistant_reply)]); return; }
      if (turn.intent === "out_of_scope" && qIndex > 0) { setMessages((current) => [...current, message("assistant", "I may not have understood that — I’m best with questions about getting set up here. If you’d rather talk to a person, you can book that in a couple of steps. For now, one of the options below works best.")]); return; }
      const recordedAnswer = turn.intent === "skip_question" ? turn.assessment_value ?? "Complete with specialist" : displayedAnswer;
      const nextAssessment = { ...assessment, [FIELDS[qIndex]]: recordedAnswer };
      setAssessment(nextAssessment);
      const next = qIndex + 1;
      const nextPrompt = next < 4 ? QUESTIONS[next] : "Here’s what I’ve noted so far.";
      const calmPacing = calmModeActive || turn.calm_mode_active;
      const additions = turn.intent === "skip_question"
        ? [message("assistant", `${turn.assistant_reply} ${nextPrompt}`)]
        : calmPacing
          ? [message("assistant", `${acknowledgment(qIndex, displayedAnswer, turn.level)} ${nextPrompt}`)]
          : [message("assistant", acknowledgment(qIndex, displayedAnswer, turn.level)), message("assistant", nextPrompt)];
      setMessages((current) => [...current, ...additions]); setQIndex(next);
    } catch (error) { setProviderError(error instanceof ApiError ? error : new ApiError("assistant_unavailable", "The assistant is temporarily unavailable.", true)); }
    finally { setTyping(false); }
  };
  const onSubmit = (event: FormEvent) => { event.preventDefault(); void submit(draft); };

  return <section className={styles.chatScreen} data-screen-label="Chat assessment"><div className={styles.intro}><h1>Let’s get you set up</h1><p>{calmModeActive ? "We’ll keep this to one small step at a time. You can pause and return whenever you need." : "A few questions, one at a time. You can pause whenever you like."}</p>{calmModeActive && <div className={styles.calmStatus}>Gentle pace is on</div>}</div><div className={styles.transcript} ref={transcript} aria-live="polite">
    {messages.map((item) => <div key={item.id} className={`${styles.bubble} ${styles[item.speaker]}`}>{item.text}</div>)}
    {typing && <div className={`${styles.bubble} ${styles.assistant} ${styles.typing}`} aria-label="Wren is typing"><i /><i /><i /></div>}
    {qIndex === 4 && <AssessmentCard assessment={assessment} />}
    {providerError && <div className={styles.warningCard} role="alert"><b>Assistant unavailable</b><p>I can’t reach the assistant service right now. Your answers are safe — you can retry in a moment, or continue with a standard form and finish the same way.</p><div><button className={styles.amberButton} onClick={() => lastAttempt && void submit(lastAttempt.answer, lastAttempt.skip)}>Retry</button><button className={styles.primaryButton} onClick={onContinue}>Continue with the form</button></div></div>}
  </div><div className={styles.chatControls}>
    {qIndex < 4 && CHIPS[qIndex] && !typing && <div className={styles.chips}>{CHIPS[qIndex].map((chip) => <button key={chip} onClick={() => void submit(chip)}>{chip}</button>)}</div>}
    {qIndex === 4 ? <div className={styles.chips}><button onClick={onContinue}>Continue to my details →</button></div> : <><form className={styles.chatInput} onSubmit={onSubmit}><label className={styles.srOnly} htmlFor="chat-answer">Your answer</label><input id="chat-answer" value={draft} onChange={(event) => setDraft(event.target.value)} disabled={typing} placeholder={qIndex === 0 ? "Type your name…" : "Or type a question…"} /><button disabled={typing || !draft.trim()}>Send</button></form>{calmModeActive && <button className={styles.skipButton} onClick={() => void submit("", true)}>Skip this question</button>}</>}
  </div></section>;
}

function AssessmentCard({ assessment }: { assessment: Record<string, string> }) {
  const rows = [["Name", assessment.name], ["Reason", assessment.reason], ["Timing", assessment.timing], ["Note for the team", assessment.note]];
  return <div className={styles.summaryCard}><div className={styles.overline}>Your assessment so far</div>{rows.map(([label, value]) => <div className={styles.summaryRow} key={label}><b>{label}</b><span>{value}</span></div>)}<small>You’ll review everything again before it’s final.</small></div>;
}

function DocumentStep({ existing, onSaved, showSupport }: { existing: Details | null; onSaved: (details: Details) => void; showSupport: (kind: keyof typeof SUPPORT) => void }) {
  const [phase, setPhase] = useState<DocPhase>(existing?.confirmed ? "saved" : "consent");
  const [consent, setConsent] = useState(false);
  const [manual, setManual] = useState(false);
  const [savedDetails, setSavedDetails] = useState<Details | null>(existing);
  const [fields, setFields] = useState({ full_name: existing?.full_name ?? "", date_of_birth: existing?.date_of_birth ?? "", address: existing?.address ?? "" });
  const [sources, setSources] = useState<Details["field_sources"]>(existing?.field_sources ?? {});
  const [error, setError] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const grantConsent = async () => { await api.consent(true); setPhase("upload"); };
  const manualEntry = () => { setManual(true); setSources({ full_name: "manual", date_of_birth: "manual", address: "manual" }); setPhase("review"); };
  const upload = async (file?: File) => {
    if (!file) return;
    setError(""); setPhase("scanning");
    try { const result = await api.upload(file); setFields({ full_name: result.fields.full_name ?? "", date_of_birth: result.fields.date_of_birth ?? "", address: result.fields.address ?? "" }); setSources(result.field_sources); setPhase("review"); }
    catch (caught) { setError(caught instanceof Error ? caught.message : "We couldn’t read that photo."); setPhase("failed"); showSupport("ocr"); }
  };
  const sample = async () => { const blob = await fetch("/sample-id-realistic.png").then((response) => response.blob()); await upload(new File([blob], "sample-id-realistic.png", { type: "image/png" })); };
  const save = async () => { setError(""); try { const result = await api.saveDetails(fields, sources); setSavedDetails(result.details); setPhase("saved"); } catch (caught) { setError(caught instanceof Error ? caught.message : "Check the fields and try again."); } };
  const complete = Object.values(fields).every((value) => value.trim());

  return <section className={styles.docScreen} data-screen-label="Document capture">
    {phase === "consent" && <><PageIntro title="Before you share a document" /><div className={styles.consentCard}><InfoRow strong="We extract three fields only" text="name, date of birth, and address." /><InfoRow strong="You confirm everything" text="before anything is saved." /><InfoRow strong="The photo is deleted" text="immediately after extraction. Nothing is sent to the language model." /></div><label className={styles.consentCheck}><input type="checkbox" checked={consent} onChange={(event) => setConsent(event.target.checked)} /> <span>I agree to Harbor processing my document photo for this purpose. I can withdraw consent and delete my data at any time.</span></label><div className={styles.actions}><button className={styles.primaryButton} disabled={!consent} onClick={() => void grantConsent()}>Continue</button><button className={styles.ghostButton} onClick={manualEntry}>Skip — I’ll type my details</button></div></>}
    {phase === "upload" && <><PageIntro title="Add a photo of your ID" /><div className={styles.dropzone}><div className={styles.idPlaceholder}><span>id photo goes here</span></div><input ref={inputRef} type="file" accept="image/jpeg,image/png" hidden onChange={(event) => void upload(event.target.files?.[0])} /><div className={styles.actions}><button className={styles.primaryButton} onClick={() => inputRef.current?.click()}>Choose a photo</button><button className={styles.outlineButton} onClick={() => void sample()}>Use sample photo</button><button className={styles.ghostButton} onClick={manualEntry}>Type details instead</button></div></div><p className={styles.caption}>JPEG or PNG, up to 8 MB. Photos are processed privately and deleted immediately after extraction.</p></>}
    {phase === "scanning" && <div className={styles.scanning}><h1>Reading your document…</h1><p>Extracting name, date of birth, and address. This takes a few seconds.</p><div className={styles.scanTrack}><i /></div></div>}
    {phase === "failed" && <div className={styles.ocrFailure} role="alert"><h1>We couldn’t read that photo</h1><p>{error || "This usually happens with glare or blur — nothing’s lost, and nothing was saved. You can try another photo, or type your details."}</p><div className={styles.actions}><button className={styles.primaryButton} onClick={() => setPhase("upload")}>Try another photo</button><button className={styles.amberButton} onClick={manualEntry}>Type details instead</button></div></div>}
    {phase === "review" && <><PageIntro title="Confirm your details" subtitle={manual ? "Type your details below — this takes about a minute." : Object.values(fields).every(Boolean) ? "We read these from your photo — please check each one before saving." : "We read most of your document. Please check the pre-filled fields and add what we couldn’t read."} /><div className={styles.fieldList}><Field label="Full legal name" value={fields.full_name} source={sources.full_name} onChange={(value) => setFields({ ...fields, full_name: value })} /><Field label="Date of birth" type="date" value={fields.date_of_birth} source={sources.date_of_birth} onChange={(value) => setFields({ ...fields, date_of_birth: value })} /><Field label="Home address" value={fields.address} source={sources.address} onChange={(value) => setFields({ ...fields, address: value })} /></div>{error && <p className={styles.error} role="alert">{error}</p>}<div className={styles.actions}><button className={styles.primaryButton} disabled={!complete} onClick={() => void save()}>These are correct</button>{!manual && <button className={styles.ghostButton} onClick={() => setPhase("upload")}>Re-take photo</button>}</div></>}
    {phase === "saved" && savedDetails && <div className={styles.successCard}><h1>Details saved</h1><p>{manual ? "Your details are confirmed and saved." : "Your details are confirmed, and the source photo has been permanently deleted."}</p><button className={styles.primaryButton} onClick={() => onSaved(savedDetails)}>Continue to booking</button></div>}
  </section>;
}

function InfoRow({ strong, text }: { strong: string; text: string }) { return <div><b>{strong}</b> — {text}</div>; }
function PageIntro({ title, subtitle }: { title: string; subtitle?: string }) { return <div className={styles.pageIntro}><h1>{title}</h1>{subtitle && <p>{subtitle}</p>}</div>; }
function Field({ label, value, source, onChange, type = "text" }: { label: string; value: string; source?: string; onChange: (value: string) => void; type?: string }) { return <label className={styles.field}><span><b>{label}</b>{source === "ocr" && <small className={styles.readPill}>Read from photo — confirm</small>}{source === "missing" && <small className={styles.missingPill}>Couldn’t read — please add</small>}</span><input type={type} value={value} onChange={(event) => onChange(event.target.value)} /></label>; }

function BookingStep({ current, onBooked }: { current: Booking | null; onBooked: (booking: Booking) => void }) {
  const [slots, setSlots] = useState<Slot[]>([]);
  const [selected, setSelected] = useState<Slot | null>(null);
  const [booked, setBooked] = useState<Booking | null>(current);
  const [error, setError] = useState("");
  useEffect(() => { api.slots().then(({ slots: value }) => setSlots(value)).catch((caught) => setError(caught.message)); }, []);
  const groups = useMemo(() => Object.groupBy(slots, (slot) => new Date(slot.starts_at).toDateString()), [slots]);
  const confirm = async () => { if (!selected) return; setError(""); try { const result = await api.book(selected.id); setBooked(result.booking); } catch (caught) { setError(caught instanceof Error ? caught.message : "That time is no longer available."); api.slots().then(({ slots: value }) => setSlots(value)); } };
  if (booked) return <section className={styles.bookingScreen} data-screen-label="Appointment booking"><div className={styles.successCard}><h1>You’re booked</h1><p><b>{formatSlot(booked.starts_at)}</b> with an onboarding specialist.</p><p>Reference <b>{booked.reference}</b>. Save this reference; email confirmation is not configured for this demo.</p><div className={styles.actions}><button className={styles.primaryButton} onClick={() => void onBooked(booked)}>Finish up</button><button className={styles.ghostButton} onClick={async () => { await api.cancelBooking(); setBooked(null); setSelected(null); }}>Reschedule</button></div></div></section>;
  return <section className={styles.bookingScreen} data-screen-label="Appointment booking"><PageIntro title="Book your first visit" subtitle="45 minutes with an onboarding specialist, by video or phone. Pick whatever suits — you can reschedule anytime." /><div className={styles.slotGrid}>{Object.entries(groups).map(([day, daySlots]) => <div className={styles.dayColumn} key={day}><h2>{new Date(day).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}</h2>{daySlots?.map((slot) => <button key={slot.id} disabled={!slot.available} className={selected?.id === slot.id ? styles.selectedSlot : ""} onClick={() => setSelected(slot)}>{new Date(slot.starts_at).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}{!slot.available && " · Taken"}</button>)}</div>)}</div>{selected && <div className={styles.confirmBar}><span><b>{formatSlot(selected.starts_at)}</b><small>with an onboarding specialist</small></span><button className={styles.primaryButton} onClick={() => void confirm()}>Confirm booking</button></div>}{error && <p className={styles.error} role="alert">{error}</p>}</section>;
}

function formatSlot(value: string) { return new Date(value).toLocaleString("en-US", { weekday: "long", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }); }

function Done({ assessment, details, booking, onDelete }: { assessment: Record<string, string>; details: Details; booking: Booking; onDelete: () => Promise<void> }) {
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState("");
  const rows = [["Name", details.full_name], ["Date of birth", details.date_of_birth], ["Address", details.address], ["Reason", assessment.reason], ["Note for the team", assessment.note], ["Appointment", `${formatSlot(booking.starts_at)} · ${booking.reference}`]].filter(([, value]) => value);
  return <section className={styles.doneScreen} data-screen-label="All set"><PageIntro title={`You’re all set, ${assessment.name || details.full_name.split(" ")[0]}.`} subtitle="Here’s everything we have. A specialist reviews it before your visit." /><div className={styles.recordCard}>{rows.map(([label, value]) => <div key={label}><b>{label}</b><span>{value}</span></div>)}<small>Your document photo was deleted after extraction. Only the fields above are stored.</small></div><div className={styles.dataCard}><h2>Your data, your call</h2><p>You can withdraw consent and delete everything we hold — your answers, details, account, and booking — at any time.</p>{confirming ? <div className={styles.deleteConfirm}><p>This removes your record, answers, account, and booking. It can’t be undone.</p><div className={styles.actions}><button className={styles.deleteButton} onClick={() => void onDelete().catch((caught) => setError(caught.message))}>Delete everything</button><button className={styles.ghostButton} onClick={() => setConfirming(false)}>Keep my data</button></div></div> : <button className={styles.deleteOutline} onClick={() => setConfirming(true)}>Delete my data</button>}{error && <p className={styles.error}>{error}</p>}</div></section>;
}

function Deleted({ onStartOver }: { onStartOver: () => void }) { return <section className={styles.deleted}><h1>Your data has been deleted</h1><p>Your account, record, answers, document details, and booking were removed. A non-identifying deletion receipt was logged.</p><button className={styles.outlineButton} onClick={onStartOver}>Start over</button></section>; }
function SupportCard({ support, onDismiss }: { support: Support; onDismiss: () => void }) { return <aside className={styles.supportCard} role="status"><button aria-label="Dismiss support message" onClick={onDismiss}>×</button><h2>{support.title}</h2><p>{support.body}</p></aside>; }
