import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Party from '@/models/Party';
import SaleMaster from '@/models/SaleMaster';
import Notification from '@/models/Notification';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    await connectDB();

    // Only check parties that have a credit limit set
    const parties = await Party.find({ creditLimit: { $gt: 0 }, status: 'a' }).lean();
    const created: string[] = [];

    for (const party of parties) {
      const creditLimit = party.creditLimit!;

      // Aggregate real-time outstanding due
      const agg = await SaleMaster.aggregate([
        { $match: { partyId: party._id, dueAmount: { $gt: 0 }, status: { $nin: ['cancelled', 'returned'] } } },
        { $group: { _id: null, total: { $sum: '$dueAmount' } } },
      ]);
      const currentDue: number = agg[0]?.total || 0;
      const usagePct = Math.round((currentDue / creditLimit) * 100);

      const sent: string[] = (party as { creditReminderSent?: string[] }).creditReminderSent || [];
      const partyLabel = party.name;
      const dueFmt = `৳${currentDue.toLocaleString()}`;
      const limitFmt = `৳${creditLimit.toLocaleString()}`;

      // Reset reminder flags if usage drops below 70% (party paid some dues)
      if (usagePct < 70 && sent.length > 0) {
        await Party.findByIdAndUpdate(party._id, { $set: { creditReminderSent: [] } });
        continue;
      }

      // ── 70% warning ──
      if (usagePct >= 70 && usagePct < 100 && !sent.includes('70pct')) {
        await Notification.create({
          type: 'credit-warning',
          title: `⚠️ Credit Limit Warning — ${partyLabel}`,
          message: `${partyLabel} has used ${usagePct}% of their credit limit (${dueFmt} out of ${limitFmt}). Please follow up on payment.`,
          link: '/sales/parties',
          read: false,
          meta: { partyId: String(party._id), usagePct, currentDue, creditLimit, reminderType: '70pct' },
        });
        await Party.findByIdAndUpdate(party._id, { $addToSet: { creditReminderSent: '70pct' } });
        created.push(`70pct:${partyLabel}`);
      }

      // ── 90% critical ──
      if (usagePct >= 90 && usagePct < 100 && !sent.includes('90pct')) {
        await Notification.create({
          type: 'credit-critical',
          title: `🚨 Credit Limit Critical — ${partyLabel}`,
          message: `${partyLabel} has used ${usagePct}% of credit limit (${dueFmt} of ${limitFmt}). New invoices will be blocked at 100%!`,
          link: '/sales/parties',
          read: false,
          meta: { partyId: String(party._id), usagePct, currentDue, creditLimit, reminderType: '90pct' },
        });
        await Party.findByIdAndUpdate(party._id, { $addToSet: { creditReminderSent: '90pct' } });
        created.push(`90pct:${partyLabel}`);
      }

      // ── 100% blocked ──
      if (usagePct >= 100 && !sent.includes('100pct')) {
        await Notification.create({
          type: 'credit-blocked',
          title: `🛑 Credit Limit Full — ${partyLabel} BLOCKED`,
          message: `${partyLabel} has reached 100% of their credit limit (${dueFmt} of ${limitFmt}). No new invoices can be created until dues are cleared.`,
          link: '/sales/parties',
          read: false,
          meta: { partyId: String(party._id), usagePct, currentDue, creditLimit, reminderType: '100pct' },
        });
        await Party.findByIdAndUpdate(party._id, { $addToSet: { creditReminderSent: '100pct' } });
        created.push(`100pct_blocked:${partyLabel}`);
      }
    }

    return NextResponse.json({ ok: true, checked: parties.length, notificationsCreated: created.length, details: created });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
