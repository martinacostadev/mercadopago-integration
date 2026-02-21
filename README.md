# MercadoPago Integration - Claude Code Skill

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that helps you integrate **MercadoPago Checkout Pro** (redirect-based) into **Next.js** applications with **any PostgreSQL database**.

## What This Skill Does

When installed, Claude will automatically guide you through a complete MercadoPago payment integration including:

- MercadoPago client setup with the official SDK
- Checkout API route with Zod validation
- Webhook handler with idempotency checks
- Purchase status verification API
- Frontend checkout hook with double-submit prevention
- Success/failure pages with server-side payment verification
- Database schema (standard PostgreSQL)

### Database Support

Works with any PostgreSQL database through a DB helper abstraction:

| Adapter | Reference File |
|---------|---------------|
| **Supabase** | `references/database-supabase.md` |
| **Prisma** (AWS RDS, Neon, etc.) | `references/database-prisma.md` |
| **Raw pg / Drizzle / Kysely** | `references/database-postgresql.md` |

### Country Support

All MercadoPago countries: Argentina (ARS), Brazil (BRL), Mexico (MXN), Colombia (COP), Chile (CLP), Peru (PEN), Uruguay (UYU).

## Installation

### Option 1: Install via skills CLI

```bash
npx skills add martinacostadev/mercadopago-integration
```

### Option 2: Install via Claude Code CLI

```bash
claude skill add --url https://github.com/martinacostadev/mercadopago-integration
```

### Option 3: Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/martinacostadev/mercadopago-integration.git
   ```

2. Copy the `mercadopago-integration` folder to your Claude Code skills directory:
   ```bash
   # macOS/Linux
   cp -r mercadopago-integration/mercadopago-integration ~/.claude/skills/

   # Windows
   xcopy /E /I mercadopago-integration\mercadopago-integration %USERPROFILE%\.claude\skills\mercadopago-integration
   ```

3. Verify installation by asking Claude:
   ```
   Integrate MercadoPago payments into my app
   ```

## Quick Start

Just ask Claude naturally:

```
Integrar MercadoPago en mi app
```

Or with more details:

```
Integrate MercadoPago Checkout Pro into my Next.js app.
Database: Prisma. Currency: ARS. Success route: /pago-exitoso. Brand: MY_STORE.
```

Or let Claude explore your codebase first:

```
Integrate MercadoPago payments using the mercadopago-integration skill.
Explore my codebase first to find the cart store, product model, and database setup.
```

See `mercadopago-integration/references/usage-examples.md` for more prompt templates.

## Skill Structure

```
mercadopago-integration/
  SKILL.md                              # Main skill instructions
  references/
    database-supabase.md                # Supabase DB helper
    database-prisma.md                  # Prisma DB helper
    database-postgresql.md              # Raw pg / Drizzle DB helper
    troubleshooting.md                  # 20+ common errors and fixes
    testing.md                          # Complete testing guide
    countries.md                        # Currencies, test cards, payment methods
    usage-examples.md                   # Ready-to-use prompts
  assets/
    migration.sql                       # Standard PostgreSQL schema template
```

## Prerequisites

Before using this skill, your project needs:

- **Next.js** (App Router)
- **PostgreSQL database** (Supabase, AWS RDS, Neon, self-hosted, etc.)
- **MercadoPago developer account** ([create one here](https://www.mercadopago.com/developers/panel/app))

## Documentation

### Testing
See `references/testing.md` for:
- Test card numbers by country
- Simulating different payment outcomes (approved, rejected, pending)
- Setting up test accounts
- Testing webhooks locally with ngrok

### Troubleshooting
See `references/troubleshooting.md` for solutions to 20+ common issues:
- `auto_return` errors
- Webhook not receiving notifications
- Currency/credential mismatches
- Hydration errors
- And more...

### Countries & Payment Methods
See `references/countries.md` for:
- Supported currencies by country
- Test cards for each country
- Available payment methods (cards, cash, bank transfer)
- Offline payment handling (Rapipago, OXXO, Boleto, etc.)

## License

MIT
