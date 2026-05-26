+++
title = "Your \"Server Component\" Is Running on the Client (And You Have No Idea)"
date = 2026-04-14T01:00:00+05:00
slug = "server-component-runs-on-client"
path = "posts/server-component-runs-on-client"
draft = false

[taxonomies]
tags = ["nextjs","react","server-components","debugging"]

[extra]
author = "Jameel Ahmad"
description = "The cases where Next.js developers are convinced their code runs on the server — but it silently runs on the client instead."
featured = true
og_image = "/assets/images/server-component-runs-on-client.jpg"
original_file_path = "src/data/blog/server-component-runs-on-client.md"
+++

You write a component. No `"use client"` directive. You fetch data directly, maybe even do a `console.log` to confirm it's running server-side. The log shows up — in your browser console.

That's the moment. The "wait, what?" moment.

![Scooby-Doo mask reveal meme: "Server Component" is actually "Runs on Client Side"](/assets/images/server-component-runs-on-client.jpg)

Next.js App Router made Server Components the default, which is great. But that default comes with a catch: it's surprisingly easy to write code you *think* is server-only but is actually being executed on the client. Here are the real cases where this happens.

## Table of contents

## Case 1: No "use client" Doesn't Mean Server Component

**The misconception:** A component will render on the server simply because you didn't add `"use client"` to the top of the file.

**The reality:** If you import and nest that component inside a parent that *is* a Client Component, it automatically inherits client behavior and runs in the browser.

```tsx
// UserProfile.tsx — no "use client", so it must be a Server Component, right?
export default function UserProfile() {
  return <div>{/* sensitive render logic */}</div>;
}

// Sidebar.tsx
"use client";

import UserProfile from "./UserProfile"; // ← now a Client Component

export default function Sidebar() {
  const [open, setOpen] = useState(false);
  return (
    <div>
      <UserProfile /> {/* running in the browser */}
    </div>
  );
}
```

`UserProfile` had no directive, but because it's *imported* inside a Client Component, it gets bundled into the client and runs there. Any server-only logic inside it — DB calls, secret env vars — silently breaks or gets exposed.

**The fix:** Pass the Server Component as `children` instead of importing it directly.

```tsx
// page.tsx (Server Component)
import Sidebar from "./Sidebar";
import UserProfile from "./UserProfile";

export default function Page() {
  return (
    <Sidebar>
      <UserProfile /> {/* still a Server Component */}
    </Sidebar>
  );
}

// Sidebar.tsx
"use client";

export default function Sidebar({ children }) {
  const [open, setOpen] = useState(false);
  return <div>{children}</div>;
}
```

Components passed as `children` or props are not pulled into the client boundary. They stay on the server.

## Case 2: Placing "use client" Too High in the Tree

**The misconception:** You put `"use client"` high up in your layout or page, assuming child components beneath it stay as Server Components since that's the Next.js default.

**The reality:** The directive at the top of the tree creates a boundary that forces the *entire subtree beneath it* to be bundled and executed on the client, completely wiping out Server Component benefits for every child.

```tsx
// app/layout.tsx
"use client"; // ← placed here to use a single useState

export default function RootLayout({ children }) {
  const [theme, setTheme] = useState("light");
  return (
    <html>
      <body>
        {/* Every single component rendered here is now a Client Component */}
        {children}
      </body>
    </html>
  );
}
```

Every page, every data-fetching component, every child that should be running on the server — is now running in the browser. You've opted your entire app out of Server Components with one misplaced directive.

**The fix:** Push `"use client"` as deep as possible. If you only need interactivity for a theme toggle button, extract *just that button* into its own file and mark that file as `"use client"`.

```tsx
// components/ThemeToggle.tsx
"use client";

export default function ThemeToggle() {
  const [theme, setTheme] = useState("light");
  return (
    <button onClick={() => setTheme(t => t === "light" ? "dark" : "light")}>
      Toggle
    </button>
  );
}

// app/layout.tsx — no "use client" needed here
import ThemeToggle from "@/components/ThemeToggle";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <ThemeToggle /> {/* only this is a Client Component */}
        {children}      {/* everything else stays on the server */}
      </body>
    </html>
  );
}
```

## Case 3: Not Separating Client and Server Utils

**The misconception:** You write utility functions for backend tasks — database queries, secret lookups — and assume they'll safely stay on the server.

**The reality:** If you accidentally import one of those server utilities into a client component, Next.js bundles that sensitive logic and ships it directly to the user's browser.

```ts
// lib/utils.ts — one file for everything
export function formatDate(date: Date) { /* safe, UI logic */ }
export async function getUserFromDb(id: string) { /* db query, secret logic */ }

// components/ProfileCard.tsx
"use client";

import { formatDate, getUserFromDb } from "@/lib/utils";
// ↑ getUserFromDb is now in the browser bundle
```

You only meant to import `formatDate`. But because both functions live in the same file, the entire module gets bundled — including your database logic.

**The fix:** Separate your utilities by environment. Keep server-only logic in dedicated files and protect them with the `server-only` package.

```ts
// lib/server/db.ts
import "server-only"; // ← hard build error if this gets imported client-side

export async function getUserFromDb(id: string) { /* safe */ }

// lib/utils.ts — only safe, UI-level helpers
export function formatDate(date: Date) { /* fine anywhere */ }
```

Now if `lib/server/db.ts` ever ends up in a client bundle, Next.js throws a build error instead of silently shipping your DB logic to users.

## Case 4: Leaking Sensitive Data Through Props

**The misconception:** You securely fetch data inside a Server Component and assume it stays secure because the fetch happened on the server.

**The reality:** If you pass that sensitive data — tokens, passwords, hidden IDs, internal pricing — down as a prop to a Client Component, it gets serialized and sent to the browser. The user can read it in full.

```tsx
// app/dashboard/page.tsx (Server Component)
export default async function DashboardPage() {
  const user = await db.query(`SELECT * FROM users WHERE id = ?`, [userId]);
  // user contains: { id, name, email, passwordHash, stripeSecretKey, internalScore }

  return <UserCard user={user} />; // ← passing the entire object down
}

// components/UserCard.tsx
"use client";

export default function UserCard({ user }) {
  // user.passwordHash and user.stripeSecretKey are now in the browser
  return <div>{user.name}</div>;
}
```

You're only *displaying* `user.name`, but the entire object was serialized into the HTML payload and shipped to the client. Anyone can inspect the network response and read the rest.

**The fix:** Pass only what the Client Component actually needs to render.

```tsx
// app/dashboard/page.tsx
export default async function DashboardPage() {
  const user = await db.query(`SELECT * FROM users WHERE id = ?`, [userId]);

  return <UserCard name={user.name} email={user.email} />; // ← only safe fields
}
```

Never pass a raw database object to a Client Component. Treat the prop boundary the same way you'd treat an API response — intentionally shape what leaves the server.

---

## Edge Case: Server Actions Aren't Private Functions

Server Actions do execute on the server, so this section is a bit different — your code *does* run server-side. But there's a fundamental misunderstanding about what that means for security.

### Adding "use server" Doesn't Make a Function Private

**The misconception:** You add `"use server"` to a function thinking it's a strict rule to "run this private utility on the server" — an internal function the outside world can't touch.

**The reality:** `"use server"` creates a **public-facing POST endpoint**. The client can invoke it at will. If you don't validate and authorize inside the action itself, you've left a door wide open.

```ts
// app/actions.ts
"use server";

export async function deleteUser(userId: string) {
  // No auth check. No ownership check.
  await db.delete("users", { id: userId }); // ← anyone can call this
}
```

This action is reachable via a POST request from any client — your app, someone else's browser tab, a curl command. The fact that it runs on your server doesn't make it safe; it makes it a publicly accessible API that does destructive work.

**The fix:** Treat every Server Action like a public API route. Verify authentication and authorization inside the action on every single call.

```ts
"use server";

import { auth } from "@/lib/auth";

export async function deleteUser(userId: string) {
  const session = await auth();
  if (!session) throw new Error("Unauthorized");
  if (session.user.role !== "admin") throw new Error("Forbidden");

  await db.delete("users", { id: userId });
}
```

Never assume a Server Action is protected because it lives in your codebase. Assume every action is reachable by anyone and validate accordingly.

---

## The Mental Model That Actually Helps

Stop thinking of Server vs. Client as a property of individual files. Think of it as **two separate execution environments**, and your code lives in whichever one its import chain puts it in.

- `"use client"` doesn't mark a component as client-only. It marks a **boundary** — the point where the server tree ends and the client bundle begins.
- Everything *imported inside* a Client Component becomes client code, regardless of its own directives.
- Everything *passed as props or children* keeps its original context.
- Server Actions are public endpoints, not private functions.

Once that clicks, the mask reveal makes sense. Your "Server Component" was always the client. You just hadn't pulled it off yet.
