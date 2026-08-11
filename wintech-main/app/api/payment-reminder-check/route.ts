import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SaleMaster from '@/models/SaleMaster';
import Notification from '@/models/Notification';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    await connectDB();

    const now = new Date();
    const todayStart = new Date(now); todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(now);   todayEnd.setHours(23, 59, 59, 999);

    const tomorrowStart = new Date(todayStart); tomorrowStart.setDate(tomorrowStart.getDate() + 1);
    const tomorrowEnd   = new Date(todayEnd);   tomorrowEnd.setDate(tomorrowEnd.getDate() + 1);

    const overdueFrom = new Date(todayStart); overdueFrom.setDate(overdueFrom.getDate() - 30); // look back 30 days

    // Orders with a probablePaymentDate set and still have due amount
    const orders = await SaleMaster.find({
      probablePaymentDate: { $gte: overdueFrom, $lte: tomorrowEnd },
      dueAmount: { $gt: 0 },
    }).lean();

    const created: string[] = [];

    for (const order of orders) {
      const payDate = new Date(order.probablePaymentDate!);
      payDate.setHours(0, 0, 0, 0);

      const sentReminders: string[] = (order as { paymentReminderSent?: string[] }).paymentReminderSent || [];

      const partyLabel = order.partyName || 'Unknown Party';
      const invoiceLabel = order.invoiceNo;
      const dueAmt = `৳${(order.dueAmount || 0).toLocaleString()}`;
      const dateLabel = payDate.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

      // ── Today reminder ──
      if (payDate >= todayStart && payDate <= todayEnd && !sentReminders.includes('due_today')) {
        await Notification.create({
          type: 'payment-due-today',
          title: `💳 Payment Due TODAY — ${partyLabel}`,
          message: `Invoice ${invoiceLabel} — Due ${dueAmt} is expected to be paid today (${dateLabel}).`,
          link: '/sales',
          read: false,
          meta: { saleId: String(order._id), invoiceNo: invoiceLabel, reminderType: 'due_today' },
        });
        await SaleMaster.findByIdAndUpdate(order._id, { $addToSet: { paymentReminderSent: 'due_today' } });
        created.push(`due_today:${invoiceLabel}`);
      }

      // ── Tomorrow reminder ──
      if (payDate >= tomorrowStart && payDate <= tomorrowEnd && !sentReminders.includes('day_before')) {
        await Notification.create({
          type: 'payment-due-tomorrow',
          title: `⏰ Payment Due Tomorrow — ${partyLabel}`,
          message: `Invoice ${invoiceLabel} — Due ${dueAmt} is expected tomorrow (${dateLabel}). Please follow up.`,
          link: '/sales',
          read: false,
          meta: { saleId: String(order._id), invoiceNo: invoiceLabel, reminderType: 'day_before' },
        });
        await SaleMaster.findByIdAndUpdate(order._id, { $addToSet: { paymentReminderSent: 'day_before' } });
        created.push(`day_before:${invoiceLabel}`);
      }

      // ── Overdue reminder (past due date, unpaid) ──
      if (payDate < todayStart && !sentReminders.includes('overdue')) {
        const daysOverdue = Math.floor((todayStart.getTime() - payDate.getTime()) / (1000 * 60 * 60 * 24));
        await Notification.create({
          type: 'payment-overdue',
          title: `🚨 Overdue Payment — ${partyLabel}`,
          message: `Invoice ${invoiceLabel} — ${dueAmt} was due on ${dateLabel} (${daysOverdue} day${daysOverdue !== 1 ? 's' : ''} overdue). Immediate follow-up needed!`,
          link: '/sales',
          read: false,
          meta: { saleId: String(order._id), invoiceNo: invoiceLabel, reminderType: 'overdue', daysOverdue },
        });
        await SaleMaster.findByIdAndUpdate(order._id, { $addToSet: { paymentReminderSent: 'overdue' } });
        created.push(`overdue:${invoiceLabel}`);
      }
    }

    return NextResponse.json({
      ok: true,
      checked: orders.length,
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
