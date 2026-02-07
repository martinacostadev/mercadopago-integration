# MercadoPago Checkout Pro - Troubleshooting

## Table of Contents

1. [auto_return + localhost = 400](#auto_return-localhost-400)
2. [Failed to create purchase (NULL email)](#failed-to-create-purchase)
3. [Hydration mismatch on checkout page](#hydration-mismatch)
4. [Double purchase on double-click](#double-purchase)
5. [Success page shows approved without real payment](#success-page-trust)
6. [Webhook not received locally](#webhook-not-received)
7. [Webhook duplicate updates](#webhook-duplicates)
8. [useSearchParams error in App Router](#usesearchparams-error)
9. [Preference creation fails with invalid items](#invalid-items)
10. [Payment stuck in pending](#payment-stuck-pending)

---

## auto_return + localhost = 400 {#auto_return-localhost-400}

**Error:** `auto_return invalid. back_url.success must be defined`

**Cause:** `auto_return: 'approved'` requires all `back_urls` to be valid HTTPS URLs. On localhost (HTTP), MercadoPago rejects the preference.

**Fix:** Conditionally set `auto_return`:

```typescript
const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

// In preference body:
...(baseUrl.startsWith('https') ? { auto_return: 'approved' as const } : {}),
```

**Note:** Without `auto_return`, the buyer must click "Return to site" manually after payment on localhost. This is fine for development.

---

## Failed to create purchase {#failed-to-create-purchase}

**Error:** 500 from `/api/checkout` - `Failed to create purchase`

**Cause:** The `user_email` column has a `NOT NULL` constraint but no email was provided at checkout time.

**Fix:** Use a placeholder that the webhook will update later:

```typescript
user_email: email || 'pending@checkout',
```

MercadoPago collects the buyer's email during payment. The webhook updates `user_email` with the real payer email from `payment.payer.email`.

---

## Hydration mismatch {#hydration-mismatch}

**Error:** React hydration mismatch warning on checkout page. Content differs between server and client.

**Cause:** Cart store uses `localStorage` (e.g., zustand with `persist` middleware). Server-side rendering has no access to `localStorage`, so it renders empty state while the client renders cart items.

**Fix:** Add a `mounted` guard:

```typescript
const [mounted, setMounted] = useState(false);
useEffect(() => { setMounted(true); }, []);

if (!mounted) return <LoadingSpinner />;
// Now safe to render cart-dependent content
```

---

## Double purchase {#double-purchase}

**Cause:** User clicks "Pay" multiple times before redirect. Each click creates a new purchase and preference.

**Fix:** Use a `useRef` flag (survives React re-renders, unlike state which may be stale in closures):

```typescript
const submittingRef = useRef(false);

const submit = async () => {
  if (submittingRef.current) return;
  submittingRef.current = true;
  // ... fetch ...
  // Only reset on error (success redirects away from the page)
};
```

Also disable the button via `isSubmitting` state for visual feedback.

---

## Success page shows approved without real payment {#success-page-trust}

**Cause:** The page trusts the MercadoPago redirect URL parameters without verifying actual payment status in the database.

**Fix:** Always verify via API:

```typescript
const res = await fetch(`/api/purchases/${purchaseId}`);
const data = await res.json();
// data.status is 'pending' | 'approved' | 'rejected'
```

The webhook updates the real status. If the webhook hasn't arrived yet, status will be `pending` - show appropriate UI.

---

## Webhook not received {#webhook-not-received}

**Cause:** MercadoPago cannot reach `localhost`. Webhooks require a publicly accessible URL.

**Fix options:**

1. **ngrok (recommended for dev):**
   ```bash
   ngrok http 3000
   ```
   Set `NEXT_PUBLIC_APP_URL` to the ngrok HTTPS URL (e.g., `https://abc123.ngrok-free.app`)

2. **Sandbox testing:** Sandbox payments trigger webhooks if the notification URL is reachable.

3. **Local-only fallback:** For local testing, rely on the redirect flow. The success page will show `pending` since the webhook never updates the status. This is acceptable for development.

---

## Webhook duplicates {#webhook-duplicates}

**Cause:** MercadoPago retries webhooks if it doesn't get a 2xx response, or sends multiple notifications for the same payment event.

**Fix:** Idempotency check before updating:

```typescript
const existing = await getPurchaseStatus(externalReference);

// Skip if already in terminal state
if (existing?.status === 'approved' || existing?.status === 'rejected') {
  return NextResponse.json({ received: true });
}
```

Always return `{ received: true }` even on errors to prevent MercadoPago from retrying indefinitely.

---

## useSearchParams error {#usesearchparams-error}

**Error:** `useSearchParams() should be wrapped in a suspense boundary at page...`

**Cause:** Next.js App Router requires `useSearchParams()` to be inside a `<Suspense>` boundary.

**Fix:**

```tsx
function SuccessContent() {
  const searchParams = useSearchParams();
  // ... component logic
}

export default function SuccessPage() {
  return (
    <Suspense fallback={<Loading />}>
      <SuccessContent />
    </Suspense>
  );
}
```

---

## Invalid items {#invalid-items}

**Error:** MercadoPago returns 400 when creating preference.

**Common causes:**
- `unit_price` is 0 or negative
- `quantity` is 0 or negative
- `currency_id` doesn't match the account's country
- `title` is empty

**Fix:** Validate with Zod before calling MercadoPago:

```typescript
const checkoutSchema = z.object({
  items: z.array(z.object({
    id: z.string(),
    title: z.string().min(1),
    quantity: z.number().positive(),
    unit_price: z.number().positive(),
  })).min(1),
});
```

---

## Payment stuck in pending {#payment-stuck-pending}

**Cause:** Several possible reasons:
1. Webhook never arrived (localhost issue)
2. Buyer used a payment method that requires time (e.g., Rapipago, PagoFacil, Boleto, OXXO)
3. MercadoPago is still processing

**Fix:**
- In dev: Verify webhook is reachable (see "Webhook not received" above)
- In production: This is normal for offline payment methods. Show appropriate UI:
  ```
  "Your payment is being processed. You'll receive an email when confirmed."
  ```
- Check MercadoPago dashboard for the payment status manually if needed
