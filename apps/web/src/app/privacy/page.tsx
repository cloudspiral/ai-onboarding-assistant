import Link from "next/link";
import styles from "./privacy.module.css";

export default function PrivacyPage() {
  return <main className={styles.page}>
    <Link href="/">← Back to Harbor</Link>
    <p className={styles.overline}>Privacy in plain language</p>
    <h1>We collect less, keep less, and show you what’s saved.</h1>
    <section>
      <h2>Your document photo</h2><p>Harbor uses local Tesseract OCR to read only your name, date of birth, and address. The raw JPEG or PNG is never stored and is destroyed immediately after extraction—even before you confirm or correct the fields. It is never sent to OpenAI.</p>
      <h2>Your conversation</h2><p>Only your structured onboarding answers are saved. Transcripts are not written to application logs. Text sent to OpenAI uses the Responses API with storage disabled; the API call metadata contains no prompt or response content.</p>
      <h2>Your control</h2><p>You can skip document upload, type details manually, revoke consent, or delete your account and all onboarding data. A deletion leaves only a one-way, non-identifying audit digest.</p>
      <h2>Service boundary</h2><p>Harbor is an onboarding tool, not a medical or crisis service. For immediate danger in the U.S., call 911. Call or text 988 for the Suicide &amp; Crisis Lifeline.</p>
    </section>
  </main>;
}
