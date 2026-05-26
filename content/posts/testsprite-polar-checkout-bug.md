+++
title = "How TestSprite Helped Me Find a Silent Polar Checkout Bug (and How I Fixed It)"
date = 2026-04-12T14:00:00+05:00
slug = "testsprite-polar-checkout-bug"
path = "posts/testsprite-polar-checkout-bug"
draft = false

[taxonomies]
tags = ["testsprite","e2e-testing","nextjs","polar","debugging"]

[extra]
author = "Jameel Ahmad"
description = "TestSprite surfaced an HTTP 500 on our billing checkout route. Here is how AI-driven E2E testing led us to the real culprit—invalid URL handling in the Polar Next.js helper—and the fix we shipped."
featured = true
og_image = "/assets/images/testsprite-polar-checkout-bug.jpg"
original_file_path = "src/data/blog/how-testsprite-caught-our-polar-checkout-bug.md"
+++

I have been building **Lucid Hire**, a Next.js recruiter dashboard with **Clerk** auth, **Neon** Postgres, and **Polar** for subscriptions. The billing page lets recruiters click **Upgrade to Pro** and navigate to Polar-hosted checkout. In manual testing I had tunneling and env quirks, so I leaned on **TestSprite**—an MCP-connected E2E runner—to exercise the full app through a real browser session.

One case kept failing: **TC013**, “Billing page remains usable after returning from external checkout.” The report was blunt: hitting `/api/billing/checkout?plan=pro` returned **HTTP 500** with a generic browser error page—no JSON, no stack trace in the UI.

![Optional hero image for the post](/assets/images/testsprite-polar-checkout-bug.jpg)

This post is about how that failure was actually a gift: TestSprite reproduced a path I had not fully validated, and chasing it led to a concrete bug in how we integrated Polar—not “Polar is down,” but **our route crashing before the SDK could even run**.

## Table of contents

## What TestSprite reported

TestSprite generates a frontend test plan, runs Playwright-style flows against my local app (via a tunnel), and writes a report under `testsprite_tests/tmp/raw_report.md`. For **TC013**, the relevant excerpt looked like this in spirit:

- The automation navigated to **`/api/billing/checkout?plan=pro`** (same as our real **Upgrade** button).
- The browser showed **“This page isn’t working”** / **HTTP ERROR 500**.
- No redirect to Polar, so the test correctly marked a **failure**.

That told me the bug was **server-side** in our checkout API route, not a flaky click in the billing UI.

## Following the trail to `src/app/api/billing/checkout/route.ts`

Our billing client triggers checkout with a full-page navigation—simple and intentional:

```tsx
const startUpgrade = (plan: "pro" | "max") => {
  setLoadingPlan(plan);
  window.location.href = `/api/billing/checkout?plan=${plan}`;
};
```

So every upgrade goes through **`GET /api/billing/checkout`**. I opened the route handler next.

Originally, the route used **`Checkout` from `@polar-sh/nextjs`**, which wraps **`@polar-sh/sdk`** and builds a checkout session from query parameters. On the surface that is the “official” integration. The problem was what happened **before** Polar’s API was called.

## The mystery of the blank 500

Inside `@polar-sh/nextjs`, the checkout handler does something like this (simplified from the published package):

```javascript
const success = successUrl ? new URL(successUrl) : void 0;
if (success && includeCheckoutId) {
  success.searchParams.set("checkoutId", "{CHECKOUT_ID}");
}
try {
  const result = await polar.checkouts.create({ /* ... */ });
  return NextResponse.redirect(redirectUrl.toString());
} catch (error) {
  console.error(error);
  return NextResponse.error();
}
```

Two important details:

1. **`new URL(successUrl)` runs outside the `try` block.**  
   In JavaScript, `new URL("/dashboard/settings/billing")` **throws**—relative URLs are invalid without a base. So if `POLAR_SUCCESS_URL` was unset in a way that still led to bad input, or was documented as a “path only” value, the handler could **throw before `try`** → Next.js responds with an **unhelpful 500** and no JSON body.

2. **When the Polar API failed, the helper returned `NextResponse.error()`.**  
   That is also an **opaque 500** from the browser’s point of view. TestSprite (and users) only see “something broke.”

Separately, our README listed **`POLAR_ACCESS_TOKEN`** and product IDs but never **`POLAR_SUCCESS_URL`**. Locally I had been “fine” until the exact combination of tunnel + env + navigation reproduced the crash in CI-style E2E.

## How TestSprite helped beyond “checkout is broken”

Without TestSprite, I might have assumed:

- “Polar credentials are wrong,” or  
- “Test user is not allowed to checkout,” or  
- “Clerk session is missing.”

The report narrowed it: **authenticated flows passed** (billing page, plan copy, other cases), but the **API route itself** returned 500 when used like a real user (**full navigation** to the API URL). That pushed me to read the **route + Polar adapter**, not redo Clerk for the tenth time.

So the value was not only automation—it was **a reproducible, user-shaped repro** attached to logs and video links in the TestSprite dashboard.

## The fix: own the checkout flow and make URLs safe

I stopped delegating to `@polar-sh/nextjs`’s `Checkout()` for this route and called **`polar.checkouts.create()`** from **`@polar-sh/sdk`** directly, with:

1. **A resolver that always produces a valid absolute success URL**  
2. **A `try/catch` that returns JSON with a real error message** (HTTP 502) when Polar rejects the request  

### 1. Resolve `POLAR_SUCCESS_URL` safely

Polar needs an **absolute** success URL. If the env var is missing, we default to returning the user to billing. If it is a relative path, we resolve it against `NEXT_PUBLIC_APP_URL`, `VERCEL_URL`, or the incoming request origin:

```typescript
function resolveCheckoutSuccessUrl(request: NextRequest): URL {
  const raw = process.env.POLAR_SUCCESS_URL?.trim();
  const origin =
    process.env.NEXT_PUBLIC_APP_URL?.replace(/\/$/, "") ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null) ||
    request.nextUrl.origin;

  if (!raw) {
    return new URL("/dashboard/settings/billing", origin);
  }

  try {
    return new URL(raw);
  } catch {
    const path = raw.startsWith("/") ? raw : `/${raw}`;
    return new URL(path, origin);
  }
}
```

Then we append Polar’s **`checkoutId={CHECKOUT_ID}`** placeholder the same way the official helper does:

```typescript
const successUrl = resolveCheckoutSuccessUrl(request);
successUrl.searchParams.set("checkoutId", "{CHECKOUT_ID}");
```

### 2. Create the session and redirect—or return a clear error

```typescript
const polar = new Polar({
  accessToken,
  server: polarServerFromEnv(),
});

try {
  const result = await polar.checkouts.create({
    products: [productId],
    successUrl: decodeURI(successUrl.toString()),
    externalCustomerId: organization.id,
    customerEmail: appUser.email,
    customerName: appUser.name ?? undefined,
    metadata: { orgId: organization.id },
  });

  return NextResponse.redirect(result.url);
} catch (error) {
  console.error("[billing/checkout] Polar API error:", error);
  return NextResponse.json(
    { error: checkoutErrorMessage(error) },
    { status: 502 },
  );
}
```

After this change:

- **Misconfiguration** (wrong token, wrong sandbox vs production product id) still fails—but the response is **JSON with a message**, and the server log has the Polar error. TestSprite (or curl) can surface that instead of a blank chrome error page.
- **Missing or relative `POLAR_SUCCESS_URL`** no longer crashes the process on `new URL()`.

## What I learned

- **E2E tools like TestSprite** are not only for “click happy paths.” They excel at **boring but exact repros**: same URL, same query string, same navigation semantics as production.
- **Third-party adapters** (`@polar-sh/nextjs`) save time until they **hide thrown errors** or **parse env in ways that assume perfect configuration**. Sometimes owning the ten lines of SDK calls buys you **observability** and **control**.
- **`POLAR_SUCCESS_URL` should be documented** next to tokens and product IDs: absolute URL preferred; if you use a path, we now resolve it—but you should still set **`NEXT_PUBLIC_APP_URL`** (or rely on `request.nextUrl.origin` in dev) so the base is correct behind proxies and tunnels.
---
