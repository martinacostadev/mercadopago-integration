# Usage Examples

Copy and adapt these prompts when asking Claude to integrate MercadoPago.

## Full Integration (New Project)

```
Integrate MercadoPago Checkout Pro following the mercadopago-integration skill.

Details:
- Currency: ARS
- Success route: /pago-exitoso
- Failure route: /pago-fallido
- Brand name (statement): MY_BRAND
- Product table: photos (id, price, title)
- Cart store: src/store/cart.ts (zustand with persist)
- Supabase server client: src/lib/supabase/server.ts (createServiceClient)

Run the migration, create all files (client, API routes, webhook, hook, success page),
and add env vars to .env.example.
```

## Add to Existing Project

```
Add MercadoPago Checkout Pro to my app using the mercadopago-integration skill.
My cart is in src/store/cart.ts, products are in the "products" table.
Currency: BRL. Success route: /payment-success. Brand: MY_STORE.
```

## Minimal Prompt (Let Claude Explore First)

```
Integrate MercadoPago payments using the mercadopago-integration skill.
Explore my codebase first to find the cart store, product model, and existing
routes before implementing.
```

## Troubleshoot Existing Integration

```
My MercadoPago integration is returning a 400 error when creating the preference.
Use the mercadopago-integration skill to diagnose and fix the issue.
```

## Add Webhook to Existing Integration

```
I already have MercadoPago checkout working but I need to add the webhook handler.
Follow the mercadopago-integration skill for the webhook implementation with
idempotency check.
```

## Brazil-Specific Integration

```
Integrate MercadoPago Checkout Pro for a Brazilian app.
Currency: BRL. Follow the mercadopago-integration skill.
Check references/countries.md for Brazil-specific payment methods and test cards.
```
