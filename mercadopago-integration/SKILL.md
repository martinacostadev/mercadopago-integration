---
name: mercadopago-integration
description: >
  Integrate MercadoPago Checkout Pro (redirect-based) into Next.js applications with
  any PostgreSQL database (Supabase, AWS RDS, Neon, PlanetScale, self-hosted, Prisma,
  Drizzle, or raw pg). Use when the user needs to: (1) Add MercadoPago payment
  processing to a Next.js app, (2) Create a checkout flow with MercadoPago, (3) Set up
  payment webhooks for MercadoPago, (4) Build payment success/failure pages, (5) Create
  a shopping cart with payment integration, (6) Troubleshoot MercadoPago integration
  issues (auto_return errors, webhook failures, hydration mismatches, double submissions).
  Triggers on requests mentioning MercadoPago, Mercado Pago, payment integration with MP,
  Argentine/Latin American payment processing, or checkout with MercadoPago. Supports
  all MercadoPago currencies (ARS, BRL, MXN, CLP, COP, PEN, UYU).
---

# MercadoPago Checkout Pro - Next.js Integration

Redirect-based payment flow: buyer clicks "Pay", is redirected to MercadoPago, completes payment, returns to the app. A webhook confirms the payment status in the background.

```
Pay button --> POST /api/checkout (create preference) --> Redirect to MercadoPago
                                                               |
MercadoPago --webhook--> /api/webhooks/mercadopago --> Update DB
          |
          +--redirect--> /payment-success?purchase=ID --> Verify via API
```

## Before Starting

1. **Determine the database adapter.** Explore the codebase or ask the user:
   - **Supabase?** See `references/database-supabase.md` for DB helper implementation
   - **Prisma?** See `references/database-prisma.md` for DB helper implementation
   - **Raw PostgreSQL (pg, Drizzle, or other)?** See `references/database-postgresql.md` for DB helper implementation

2. **Gather or infer from the codebase:**

| Detail | Why | Example |
|--------|-----|---------|
| Currency | Preference creation | `ARS`, `BRL`, `MXN` (see `references/countries.md`) |
| Success/failure routes | `back_urls` in preference | `/payment-success`, `/pago-exitoso` |
| Brand name | Card statement descriptor | `MY_STORE` |
| Product/item table | FK in `purchase_items` | `products`, `photos`, `courses` |
| Cart store location | Hook reads items from it | `src/store/cart.ts` |
| DB client path | API routes import it | `src/lib/supabase/server.ts`, `src/lib/prisma.ts` |

## Prerequisites

1. Install dependencies: `npm install mercadopago zod`
2. Set environment variables (**never** prefix access token with `NEXT_PUBLIC_`):
   ```env
   MERCADOPAGO_ACCESS_TOKEN=TEST-xxxx   # from https://www.mercadopago.com/developers/panel/app
   NEXT_PUBLIC_APP_URL=http://localhost:3000  # HTTPS in production
   ```
3. Run database migration from `assets/migration.sql` (works on any PostgreSQL database).

## Implementation Steps

### Step 1: Database Helper

**Create:** `src/lib/db/purchases.ts`

This abstracts all purchase DB operations. Implement using your DB adapter.
See the reference file for your adapter:
- Supabase: `references/database-supabase.md`
- Prisma: `references/database-prisma.md`
- Raw pg / other: `references/database-postgresql.md`

The helper must export these functions:

```typescript
interface PurchaseInsert {
  user_email: string;
  status: 'pending';
  total_amount: number;
}

interface PurchaseUpdate {
  status?: 'pending' | 'approved' | 'rejected';
  mercadopago_payment_id?: string;
  mercadopago_preference_id?: string;
  user_email?: string;
  updated_at?: string;
}

// Required exports:
export async function createPurchase(data: PurchaseInsert): Promise<{ id: string }>;
export async function updatePurchase(id: string, data: PurchaseUpdate): Promise<void>;
export async function getPurchaseStatus(id: string): Promise<{ id: string; status: string } | null>;
export async function createPurchaseItems(purchaseId: string, items: { item_id: string; price: number }[]): Promise<void>;
```

### Step 2: MercadoPago Client

**Create:** `src/lib/mercadopago/client.ts`

```typescript
import { MercadoPagoConfig, Preference, Payment } from 'mercadopago';

const client = new MercadoPagoConfig({
  accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN!,
});

const preference = new Preference(client);
const payment = new Payment(client);

interface CreatePreferenceParams {
  items: { id: string; title: string; quantity: number; unit_price: number }[];
  purchaseId: string;
  buyerEmail?: string;
}

export async function createPreference({
  items, purchaseId, buyerEmail,
}: CreatePreferenceParams) {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

  return preference.create({
    body: {
      items: items.map((item) => ({
        id: item.id,
        title: item.title,
        quantity: item.quantity,
        unit_price: item.unit_price,
        currency_id: 'ARS', // Change per references/countries.md
      })),
      ...(buyerEmail ? { payer: { email: buyerEmail } } : {}),
      back_urls: {
        success: `${baseUrl}/payment-success?purchase=${purchaseId}`,
        failure: `${baseUrl}/payment-failure?purchase=${purchaseId}`,
        pending: `${baseUrl}/payment-success?purchase=${purchaseId}&status=pending`,
      },
      // CRITICAL: auto_return requires HTTPS. Omit on localhost or MP returns 400.
      ...(baseUrl.startsWith('https') ? { auto_return: 'approved' as const } : {}),
      external_reference: purchaseId,
      notification_url: `${baseUrl}/api/webhooks/mercadopago`,
      statement_descriptor: 'YOUR_BRAND', // Replace with user's brand
      expires: true,
      expiration_date_from: new Date().toISOString(),
      expiration_date_to: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    },
  });
}

export async function getPayment(paymentId: string) {
  return payment.get({ id: paymentId });
}
```

### Step 3: Checkout API Route

**Create:** `src/app/api/checkout/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { createPurchase, updatePurchase } from '@/lib/db/purchases';
import { createPreference } from '@/lib/mercadopago/client';
import { z } from 'zod';

const checkoutSchema = z.object({
  items: z.array(z.object({
    id: z.string(),
    title: z.string(),
    quantity: z.number().positive(),
    unit_price: z.number().positive(),
  })).min(1),
  email: z.string().email().optional(),
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const validation = checkoutSchema.safeParse(body);
    if (!validation.success) {
      return NextResponse.json({ error: 'Invalid request data' }, { status: 400 });
    }

    const { items, email } = validation.data;
    const totalAmount = items.reduce((sum, i) => sum + i.unit_price * i.quantity, 0);

    const purchase = await createPurchase({
      user_email: email || 'pending@checkout',
      status: 'pending',
      total_amount: totalAmount,
    });

    const mpPreference = await createPreference({
      items, purchaseId: purchase.id, buyerEmail: email,
    });

    await updatePurchase(purchase.id, {
      mercadopago_preference_id: mpPreference.id,
    });

    return NextResponse.json({
      preferenceId: mpPreference.id,
      initPoint: mpPreference.init_point,
      purchaseId: purchase.id,
    });
  } catch (error) {
    console.error('Checkout error:', error);
    return NextResponse.json({ error: 'Checkout failed' }, { status: 500 });
  }
}
```

### Step 4: Webhook Handler

**Create:** `src/app/api/webhooks/mercadopago/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { getPurchaseStatus, updatePurchase } from '@/lib/db/purchases';
import { getPayment } from '@/lib/mercadopago/client';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    if (body.type !== 'payment' && body.action !== 'payment.created' && body.action !== 'payment.updated') {
      return NextResponse.json({ received: true });
    }

    const paymentId = body.data?.id;
    if (!paymentId) return NextResponse.json({ received: true });

    const payment = await getPayment(paymentId.toString());
    if (!payment?.external_reference) return NextResponse.json({ received: true });

    let status: 'pending' | 'approved' | 'rejected' = 'pending';
    if (payment.status === 'approved') status = 'approved';
    else if (['rejected', 'cancelled', 'refunded'].includes(payment.status || '')) status = 'rejected';

    // Idempotency: skip if already in terminal state
    const existing = await getPurchaseStatus(payment.external_reference);
    if (existing?.status === 'approved' || existing?.status === 'rejected') {
      return NextResponse.json({ received: true });
    }

    const payerEmail = payment.payer?.email;
    await updatePurchase(payment.external_reference, {
      status,
      mercadopago_payment_id: paymentId.toString(),
      ...(payerEmail ? { user_email: payerEmail } : {}),
      updated_at: new Date().toISOString(),
    });

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}

// GET endpoint for MercadoPago verification pings
export async function GET() {
  return NextResponse.json({ status: 'ok' });
}
```

### Step 5: Purchase Status API

**Create:** `src/app/api/purchases/[id]/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { getPurchaseStatus } from '@/lib/db/purchases';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const data = await getPurchaseStatus(id);

  if (!data) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  return NextResponse.json({ id: data.id, status: data.status });
}
```

### Step 6: Checkout Hook (Frontend)

**Create:** `src/hooks/useCheckout.ts`

Double-click prevention uses `useRef` (survives re-renders, unlike `useState`).

```typescript
'use client';
import { useCallback, useRef, useState } from 'react';

export function useCheckout() {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const guard = useRef(false);

  const submitCheckout = useCallback(async (items: unknown[]) => {
    if (guard.current) return;
    setError(null);
    guard.current = true;
    setIsSubmitting(true);
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Checkout failed');
      if (data.initPoint) window.location.href = data.initPoint;
      else throw new Error('No payment link returned');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
      setIsSubmitting(false);
      guard.current = false;
    }
  }, []);

  return { submitCheckout, isSubmitting, error };
}
```

### Step 7: Success Page with Verification

**Create:** `src/app/payment-success/page.tsx` (adjust route name)

Always verify purchase status server-side. Never trust the redirect URL alone.
Wrap `useSearchParams` in `<Suspense>` (Next.js App Router requirement).

```tsx
'use client';
import { useSearchParams } from 'next/navigation';
import { Suspense, useCallback, useEffect, useState } from 'react';

type Status = 'loading' | 'approved' | 'pending' | 'rejected' | 'error';

function PaymentResult() {
  const purchaseId = useSearchParams().get('purchase');
  const [status, setStatus] = useState<Status>(purchaseId ? 'loading' : 'approved');

  const verify = useCallback(async (id: string) => {
    try {
      const res = await fetch(`/api/purchases/${id}`);
      if (!res.ok) { setStatus('error'); return; }
      const { status } = await res.json();
      setStatus(status === 'approved' ? 'approved'
        : status === 'pending' ? 'pending' : 'rejected');
    } catch { setStatus('error'); }
  }, []);

  useEffect(() => { if (purchaseId) verify(purchaseId); }, [purchaseId, verify]);

  // Render UI based on status: loading/approved/pending/rejected/error
  return <div>{/* Customize UI per status */}</div>;
}

export default function PaymentSuccessPage() {
  return <Suspense fallback={<div>Loading...</div>}><PaymentResult /></Suspense>;
}
```

## Critical Gotchas

For detailed solutions, see `references/troubleshooting.md`.

| Gotcha | Fix |
|--------|-----|
| `auto_return` + localhost = 400 error | Only set when URL starts with `https` |
| `user_email NOT NULL` + no email = 500 | Use `'pending@checkout'` placeholder; webhook updates it |
| Hydration mismatch (localStorage cart) | Add `mounted` state guard before rendering cart content |
| Double purchase on double-click | Use `useRef` guard, not just `useState` |
| Success page trusts redirect URL | Always verify via `/api/purchases/[id]` |
| Webhook duplicate updates | Check if purchase is already terminal before updating |
| Webhooks can't reach localhost | Use ngrok: `ngrok http 3000` |
| `useSearchParams` error | Wrap component in `<Suspense>` |

## Checklist

- [ ] `mercadopago` + `zod` installed
- [ ] `MERCADOPAGO_ACCESS_TOKEN` in `.env` (TEST token for dev, never `NEXT_PUBLIC_`)
- [ ] `NEXT_PUBLIC_APP_URL` in `.env` (HTTPS in production)
- [ ] Database migration run (`purchases` + `purchase_items`)
- [ ] DB helper implemented (`src/lib/db/purchases.ts`)
- [ ] `/api/checkout` with Zod validation
- [ ] `/api/webhooks/mercadopago` with idempotency check
- [ ] `/api/purchases/[id]` for status verification
- [ ] Success page verifies status (not trusting redirect)
- [ ] `auto_return` only for HTTPS
- [ ] Checkout hook prevents double submit
- [ ] `useSearchParams` wrapped in `<Suspense>`

## References

- `references/database-supabase.md` - Supabase DB helper implementation
- `references/database-prisma.md` - Prisma DB helper implementation
- `references/database-postgresql.md` - Raw PostgreSQL (pg, Drizzle, etc.) DB helper implementation
- `references/troubleshooting.md` - Detailed error fixes and solutions
- `references/countries.md` - Currencies, available countries, and MercadoPago specifics
- `references/usage-examples.md` - Ready-to-use prompt templates
- `assets/migration.sql` - Database schema template (standard PostgreSQL)
- [MercadoPago Checkout Pro Docs](https://www.mercadopago.com.ar/developers/es/docs/checkout-pro/landing)
- [MercadoPago Node SDK](https://github.com/mercadopago/sdk-nodejs)
