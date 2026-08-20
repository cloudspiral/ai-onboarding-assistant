"use client";

import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import styles from "./admin.module.css";

type Analytics = Awaited<ReturnType<typeof api.adminAnalytics>>;

export default function AdminPage() {
  const [data, setData] = useState<Analytics | null>(null);
  const [error, setError] = useState("");
  const [email, setEmail] = useState("admin@harbor.example");
  const [password, setPassword] = useState("");
  const load = () => api.adminAnalytics().then((value) => { setData(value); setError(""); }).catch((caught) => setError(caught.message));
  useEffect(() => { void load(); }, []);
  const signIn = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    try { await api.signIn(email, password); await load(); }
    catch (caught) { setError(caught instanceof Error ? caught.message : "Sign-in failed."); }
  };

  return <main className={styles.page}>
    <header><div><Link href="/">Harbor</Link><span>Operations</span></div><b>Aggregate, non-identifying analytics</b></header>
    <section>
      <p className={styles.overline}>Onboarding health</p><h1>Where people make progress</h1>
      <p className={styles.subtitle}>Counts and timing only. This dashboard never includes names, answers, document text, or contact details.</p>
      {error && !data && <form className={styles.login} onSubmit={signIn}><h2>Admin sign-in</h2><p>{error}</p><label>Email<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" /></label><label>Password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" /></label><button>Sign in</button></form>}
      {!data && !error && <p>Loading analytics…</p>}
      {data && <>
        <div className={styles.metrics}><Metric label="Sessions" value={data.totals.sessions} /><Metric label="Completed" value={data.totals.completed} /><Metric label="Bookings" value={data.totals.bookings} /><Metric label="OCR success" value={`${data.ocr.successes ?? 0}/${data.ocr.attempts ?? 0}`} /></div>
        <div className={styles.grid}>
          <Panel title="Current funnel">{Object.entries(data.funnel).map(([label, value]) => <Bar key={label} label={label} value={value} max={data.totals.sessions || 1} />)}</Panel>
          <Panel title="Average step time">{Object.entries(data.step_duration_ms).map(([label, value]) => <div className={styles.row} key={label}><span>{label}</span><b>{(value / 1000).toFixed(1)}s</b></div>)}</Panel>
          <Panel title="Event activity">{Object.entries(data.events).map(([label, value]) => <div className={styles.row} key={label}><span>{label.replaceAll("_", " ")}</span><b>{value}</b></div>)}</Panel>
          <Panel title="Privacy guard"><p className={styles.privacy}>PII present: <b>{data.contains_pii ? "Yes" : "No"}</b></p><p>Anonymous session IDs power the aggregates; raw chat and OCR contents are excluded.</p></Panel>
        </div>
      </>}
    </section>
  </main>;
}

function Metric({ label, value }: { label: string; value: number | string }) { return <article className={styles.metric}><span>{label}</span><b>{value}</b></article>; }
function Panel({ title, children }: { title: string; children: ReactNode }) { return <article className={styles.panel}><h2>{title}</h2>{children}</article>; }
function Bar({ label, value, max }: { label: string; value: number; max: number }) { return <div className={styles.bar}><div><span>{label}</span><b>{value}</b></div><i><em style={{ width: `${Math.max((value / max) * 100, value ? 4 : 0)}%` }} /></i></div>; }
