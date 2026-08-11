# Wintech Agro BD — ERP System

A comprehensive Enterprise Resource Planning (ERP) system built for **Wintech Agro BD** — a fish import and distribution company. Fish is imported from India, received at the Camila Depot, and distributed to branches across the country.

## Tech Stack

- **Framework**: Next.js 15 (App Router) with React 19
- **Language**: TypeScript
- **Styling**: Tailwind CSS with dark mode support (`darkMode: 'class'`)
- **State**: Zustand with localStorage persistence
- **Charts**: Recharts
- **Icons**: Lucide React
- **Theme**: next-themes (light / dark toggle)

## Modules

| Module | Routes |
|--------|--------|
| Dashboard | `/dashboard` |
| Reports | `/reports/*` |
| Inventory | `/inventory/*` |
| Sales | `/sales/*` |
| Purchases | `/purchases/*` |
| Accounting | `/accounting/*` |
| Expenses | `/expenses/*` |
| HR | `/hr/*` |
| CRM | `/crm/*` |
| Projects | `/projects/*` |
| Assets | `/assets/*` |
| Targets | `/targets/*` |
| Settings | `/settings` |

## Running the App

```bash
npm run dev     # dev server on port 5000
npm run build   # production build
npm start       # production server on port 5000
```

> **Port must always stay at 5000.** Replit's webview preview only supports port 5000 for web apps. Using any other port (e.g. 5303) will break the live preview entirely — the app won't be visible in the browser pane. Do not change `-p 5000` in the dev/start scripts.

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@wintechagro.com | admin123 |
| Manager | manager@wintechagro.com | manager123 |
| Employee | employee@wintechagro.com | emp123 |

## User Preferences

- Company name: **Wintech Agro BD** (short: **WINTECH AGRO BD**)
- Business: Fish import from India → Camila Depot → Branch distribution
- All branding should use "Wintech Agro BD" — never "ORIENT" or "Moon ERP"
- Brand color: Emerald/Green (fish/agro theme)
- Brand icon: Fish (lucide-react `Fish` icon)
- Dark mode toggle in sidebar above logout button
- Sidebar is module-isolated (each module shows only its own sub-items)
- Module order is drag-and-drop reorderable (saved to localStorage)
- Sidebar hidden on mobile; hamburger opens slide-in drawer
