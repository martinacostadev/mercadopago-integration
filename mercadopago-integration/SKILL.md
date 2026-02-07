---
name: mercadopago-integration
description: >
  Integrate MercadoPago Checkout Pro (redirect-based) into Next.js applications with
  Supabase as the database. Use when the user needs to: (1) Add MercadoPago payment
  processing to a Next.js app, (2) Create a checkout flow with MercadoPago, (3) Set up
  payment webhooks for MercadoPago, (4) Build payment success/failure pages, (5) Create
  a shopping cart with payment integration, (6) Troubleshoot MercadoPago integration
  issues (auto_return errors, webhook failures, hydration mismatches, double submissions).
  Triggers on requests mentioning MercadoPago, Mercado Pago, payment integration with MP,
  Argentine/Latin American payment processing, or checkout with MercadoPago. Supports
  all MercadoPago currencies (ARS, BRL, MXN, CLP, COP, PEN, UYU).
---

# MercadoPago Checkout Pro - Next.js + Supabase

Redirect-based payment flow: buyer clicks "Pay", is redirected to MercadoPago, completes payment, returns to the app. A webhook confirms the payment status in the background.

```
Pay button --> POST /api/checkout (create preference) --> Redirect to MercadoPago
                                                               |
MercadoPago --webhook--> /api/webhooks/mercadopago --> Update DB
          |
          +--redirect--> /payment-success?purchase=ID --> Verify via API
```

## Before Starting

Gather or infer from the codebase:

| Detail | Why | Example |
|--------|-----|---------|
| Currency | Preference creation | `ARS`, `BRL`, `MXN` (see `references/countries.md`) |
| Success/failure routes | `back_urls` in preference | `/payment-success`, `/pago-exitoso` |
| Brand name | Card statement descriptor | `MY_STORE` |
| Product/item table | FK in `purchase_items` | `products`, `photos`, `courses` |
| Cart store location | Hook reads items from it | `src/store/cart.ts` |
| Supabase client path | API routes need it | `src/lib/supabase/server.ts` |

## Prerequisites

1. Install dependencies: `npm install mercadopago zod`
2. Set environment variables (**never** prefix access token with `NEXT_PUBLIC_`):
   ```env
   MERCADOPAGO_ACCESS_TOKEN=TEST-xxxx   # from https://www.mercadopago.com/developers/panel/app
   NEXT_PUBLIC_APP_URL=http://localhost:3000  # HTTPS in production
   ```
3. Run database migration from `assets/migration.sql` in Supabase SQL Editor.

## Implementation Steps

### Step 1: MercadoPago Client

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

### Step 2: Checkout API Route

**Create:** `src/app/api/checkout/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/server';
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

    const supabase = await createServiceClient();
    const { data: purchase, error: purchaseError } = await supabase
      .from('purchases')
      .insert({
        user_email: email || 'pending@checkout',
        status: 'pending',
        total_amount: totalAmount,
      })
      .select().single();

    if (purchaseError || !purchase) {
      console.error('Error creating purchase:', purchaseError);
      return NextResponse.json({ error: 'Failed to create purchase' }, { status: 500 });
    }

    const mpPreference = await createPreference({
      items, purchaseId: purchase.id, buyerEmail: email,
    });

    await supabase.from('purchases')
      .update({ mercadopago_preference_id: mpPreference.id })
      .eq('id', purchase.id);

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

### Step 3: Webhook Handler

**Create:** `src/app/api/webhooks/mercadopago/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/server';
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

    const supabase = await createServiceClient();

    // Idempotency: skip if already in terminal state
    const { data: existing } = await supabase
      .from('purchases').select('status').eq('id', payment.external_reference).single();
    if (existing?.status === 'approved' || existing?.status === 'rejected') {
      return NextResponse.json({ received: true });
    }

    const payerEmail = payment.payer?.email;
    await supabase.from('purchases').update({
      status,
      mercadopago_payment_id: paymentId.toString(),
      ...(payerEmail ? { user_email: payerEmail } : {}),
      updated_at: new Date().toISOString(),
    }).eq('id', payment.external_reference);

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

### Step 4: Purchase Status API

**Create:** `src/app/api/purchases/[id]/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/server';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const supabase = await createServiceClient();
  const { data, error } = await supabase
    .from('purchases').select('id, status').eq('id', id).single();

  if (error || !data) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  return NextResponse.json({ id: data.id, status: data.status });
}
```

### Step 5: Checkout Hook (Frontend)

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

### Step 6: Success Page with Verification

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

These are the most common pitfalls. For detailed solutions, see `references/troubleshooting.md`.

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
- [ ] `/api/checkout` with Zod validation
- [ ] `/api/webhooks/mercadopago` with idempotency check
- [ ] `/api/purchases/[id]` for status verification
- [ ] Success page verifies status (not trusting redirect)
- [ ] `auto_return` only for HTTPS
- [ ] Checkout hook prevents double submit
- [ ] `useSearchParams` wrapped in `<Suspense>`

## References

- `references/troubleshooting.md` - Detailed error fixes and solutions
- `references/countries.md` - Currencies, available countries, and MercadoPago specifics
- `references/usage-examples.md` - Ready-to-use prompt templates
- `assets/migration.sql` - Database schema template
- [MercadoPago Checkout Pro Docs](https://www.mercadopago.com.ar/developers/es/docs/checkout-pro/landing)
- [MercadoPago Node SDK](https://github.com/mercadopago/sdk-nodejs)
