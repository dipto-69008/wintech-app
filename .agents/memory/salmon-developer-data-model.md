---
name: Salmon Developer data model conventions
description: Team, badge, and commission system storage conventions for the Salmon Developer Flutter app — read before extending these features.
---

- Team system is single-team-per-user (not multi-team membership), stored as one team object under a SharedPreferences key rather than a list of memberships. Join requests are a separate list. Keep new team features consistent with single-team-per-user unless the user explicitly asks to generalize it.
- Badge tiers are driven by a `totalSales` threshold on the user (Bronze default, Silver/Gold/Platinum at increasing totals), each tier maps to a fixed commission rate. When adding new sales/commission flows, compute against `totalSales` rather than introducing a parallel tally.
- Demo accounts (`getDemoUser`) needed synthetic `totalSales`/`totalCommission`/`thana` values added so badge/commission UI has visible data out of the box — remember demo accounts when adding any new profile-driven feature, or it will look empty for reviewers logging in with demo creds.
