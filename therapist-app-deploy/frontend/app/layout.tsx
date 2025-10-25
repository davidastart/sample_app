import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Therapist Office App',
  description: 'HIPAA-compliant treatment planning application',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
