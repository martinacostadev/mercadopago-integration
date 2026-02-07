# MercadoPago Integration - Claude Code Skill

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that helps you integrate **MercadoPago Checkout Pro** (redirect-based) into **Next.js + Supabase** applications.

## What This Skill Does

When installed, Claude will automatically guide you through a complete MercadoPago payment integration including:

- MercadoPago client setup with the official SDK
- Checkout API route with Zod validation
- Webhook handler with idempotency checks
- Purchase status verification API
- Frontend checkout hook with double-submit prevention
- Success/failure pages with server-side payment verification
- Database schema (Supabase/PostgreSQL)

Supports all MercadoPago countries: Argentina (ARS), Brazil (BRL), Mexico (MXN), Colombia (COP), Chile (CLP), Peru (PEN), Uruguay (UYU).

## Installation

### Option 1: Install via Claude Code CLI

```bash
claude skill add --url https://github.com/martinacostadev/mercadopago-integration
```

### Option 2: Manual Installation

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

## Usage

Once installed, just ask Claude naturally:

```
Integrate MercadoPago Checkout Pro into my Next.js app.
Currency: ARS. Success route: /pago-exitoso. Brand: MY_STORE.
```

Or let Claude explore your codebase first:

```
Integrate MercadoPago payments using the mercadopago-integration skill.
Explore my codebase first to find the cart store and product model.
```

See `mercadopago-integration/references/usage-examples.md` for more prompt templates.

## Skill Structure

```
mercadopago-integration/
  SKILL.md                          # Main skill instructions
  references/
    troubleshooting.md              # Common errors and fixes
    countries.md                    # Currencies, test cards, payment methods
    usage-examples.md               # Ready-to-use prompts
  assets/
    migration.sql                   # Database schema template
```

## Prerequisites

Before using this skill, your project needs:

- **Next.js** (App Router)
- **Supabase** project with access to SQL Editor
- **MercadoPago developer account** ([create one here](https://www.mercadopago.com/developers/panel/app))

## License

MIT
