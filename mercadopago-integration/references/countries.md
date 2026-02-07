# MercadoPago - Countries, Currencies & Configuration

## Supported Countries

| Country | Currency | `currency_id` | MP Developer Portal |
|---------|----------|---------------|---------------------|
| Argentina | Peso argentino | `ARS` | mercadopago.com.ar/developers |
| Brazil | Real | `BRL` | mercadopago.com.br/developers |
| Mexico | Peso mexicano | `MXN` | mercadopago.com.mx/developers |
| Colombia | Peso colombiano | `COP` | mercadopago.com.co/developers |
| Chile | Peso chileno | `CLP` | mercadopago.cl/developers |
| Peru | Sol | `PEN` | mercadopago.com.pe/developers |
| Uruguay | Peso uruguayo | `UYU` | mercadopago.com.uy/developers |

## Important Currency Notes

- The `currency_id` in the preference **must match the country of the MercadoPago account**. An Argentine account can only use `ARS`.
- Cross-border payments are not supported via Checkout Pro. Each country requires its own MP account.
- `CLP` and `COP` do not support decimal amounts. Use whole numbers only.

## Test Credentials

Each country has separate test credentials. Get them from:
`https://www.mercadopago.com/developers/panel/app`

Test credentials include:
- **Public Key:** Starts with `TEST-` (safe for frontend, `NEXT_PUBLIC_` prefix OK)
- **Access Token:** Starts with `TEST-` (backend only, **never** expose to frontend)

## Test Cards by Country

### Argentina (ARS)
| Card | Number | CVV | Expiry |
|------|--------|-----|--------|
| Visa (approved) | 4509 9535 6623 3704 | 123 | 11/25 |
| Mastercard (approved) | 5031 7557 3453 0604 | 123 | 11/25 |
| Visa (rejected) | 4000 0000 0000 0036 | 123 | 11/25 |

### Brazil (BRL)
| Card | Number | CVV | Expiry |
|------|--------|-----|--------|
| Visa (approved) | 4235 6477 2802 5682 | 123 | 11/25 |
| Mastercard (approved) | 5031 4332 1540 6351 | 123 | 11/25 |

### Mexico (MXN)
| Card | Number | CVV | Expiry |
|------|--------|-----|--------|
| Visa (approved) | 4075 5957 1648 3764 | 123 | 11/25 |

For all test cards, use any name and a valid-format document number (DNI, CPF, etc.).

See the full list at: https://www.mercadopago.com/developers/en/docs/checkout-pro/additional-content/your-integrations/test/cards

## Payment Methods by Country

### Argentina
- Credit cards: Visa, Mastercard, Amex, Naranja, Cabal
- Debit cards: Visa Debito, Mastercard Debito, Maestro
- Cash: Rapipago, Pago Facil
- Bank transfer: Available

### Brazil
- Credit cards: Visa, Mastercard, Amex, Elo, Hipercard
- Debit cards: Available
- Cash/Boleto: Boleto Bancario
- Pix: Available (instant payment)

### Mexico
- Credit cards: Visa, Mastercard, Amex
- Cash: OXXO, PayCash
- Bank transfer: SPEI

### Colombia
- Credit cards: Visa, Mastercard, Amex, Diners
- Cash: Efecty, Baloto
- Bank transfer: PSE

### Chile
- Credit cards: Visa, Mastercard, Amex, Diners
- Debit cards: Redcompra
- Bank transfer: Webpay

### Peru
- Credit cards: Visa, Mastercard, Amex, Diners
- Cash: PagoEfectivo

### Uruguay
- Credit cards: Visa, Mastercard, Amex, Diners
- Debit cards: Available

## Notification URL Requirements

- Must be HTTPS in production
- Must be publicly accessible (not localhost)
- Must return HTTP 200 or 201
- Maximum response time: 500ms recommended (MP retries on timeout)
- For local development, use ngrok: `ngrok http 3000`
