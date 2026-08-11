import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Product from '@/models/Product';
import Notification from '@/models/Notification';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    await connectDB();

    const now = new Date();
    const in3Months = new Date(now); in3Months.setMonth(in3Months.getMonth() + 3);
    const in2Months = new Date(now); in2Months.setMonth(in2Months.getMonth() + 2);

    // Products expiring within 3 months from now
    const expiring = await Product.find({
      expiryDate: { $gte: now, $lte: in3Months },
      status: 'a',
    }).lean();

    const created: string[] = [];

    for (const p of expiring) {
      const expiry = new Date(p.expiryDate!);
      const daysLeft = Math.ceil((expiry.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      const sentReminders: string[] = (p as { expiryReminderSent?: string[] }).expiryReminderSent || [];

      // 3-month reminder (60–92 days)
      if (daysLeft <= 92 && daysLeft > 60 && !sentReminders.includes('3month')) {
        await Notification.create({
          type: 'expiry-warning',
          title: `⚠️ Expiry Alert — ${p.name}`,
          message: `"${p.name}" (${p.packSize || p.code}) expires in ~3 months on ${expiry.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}. Please review stock.`,
          link: '/inventory',
          read: false,
          meta: { productId: String(p._id), expiryDate: p.expiryDate, reminderType: '3month' },
        });
        await Product.findByIdAndUpdate(p._id, {
          $addToSet: { expiryReminderSent: '3month' },
        });
        created.push(`3month:${p.name}`);
      }

      // 2-month reminder (0–60 days)
      if (daysLeft <= 60 && daysLeft > 0 && !sentReminders.includes('2month')) {
        await Notification.create({
          type: 'expiry-critical',
          title: `🚨 Expiry Critical — ${p.name}`,
          message: `"${p.name}" (${p.packSize || p.code}) expires in ~2 months on ${expiry.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}. Urgent action needed!`,
          link: '/inventory',
          read: false,
          meta: { productId: String(p._id), expiryDate: p.expiryDate, reminderType: '2month' },
        });
        await Product.findByIdAndUpdate(p._id, {
          $addToSet: { expiryReminderSent: '2month' },
        });
        created.push(`2month:${p.name}`);
      }
    }

    return NextResponse.json({
      ok: true,
      checked: expiring.length,
      notificationsCreated: created.length,
      details: created,
    });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}
