import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Harbor · Specialized services onboarding",
  description: "Private, supportive onboarding with Harbor",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
