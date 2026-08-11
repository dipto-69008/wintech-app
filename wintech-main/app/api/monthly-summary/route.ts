import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SalesDuesReport from '@/models/SalesDuesReport';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const months = parseInt(searchParams.get('months') || '6');

    // Get last N months
    const now = new Date();
    const periods: { year: number; month: number }[] = [];
    for (let i = months - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      periods.push({ year: d.getFullYear(), month: d.getMonth() + 1 });
    }

    // Aggregate from salesduesreports
    const agg = await SalesDuesReport.aggregate([
      {
        $match: {
          $or: periods.map(p => ({ year: p.year, month: p.month })),
        },
      },
      {
        $group: {
          _id: { year: '$year', month: '$month' },
          totalSales:      { $sum: '$totalSales' },
          totalDues:       { $sum: '$totalDues' },
          totalCollection: { $sum: '$collectionAmount' },
          previousDue:     { $sum: '$previousDue' },
        },
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]);

    const MONTH_SHORT = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    // Merge with periods so we always have all months (even empty ones)
    const result = periods.map(p => {
      const found = agg.find(a => a._id.year === p.year && a._id.month === p.month);
      return {
        month: MONTH_SHORT[p.month - 1],
        year: p.year,
        monthNum: p.month,
        sales:      found?.totalSales      ?? 0,
        dues:       found?.totalDues       ?? 0,
        collection: found?.totalCollection ?? 0,
        previousDue: found?.previousDue    ?? 0,
      };
    });

    // Overall totals
    const totalRevenue  = agg.reduce((s, r) => s + r.totalSales, 0);
    const totalDues     = agg.reduce((s, r) => s + r.totalDues, 0);
    const totalCollection = agg.reduce((s, r) => s + r.totalCollection, 0);

    // This month
    const curMonth = agg.find(a => a._id.year === now.getFullYear() && a._id.month === now.getMonth() + 1);
    const thisMonthSales = curMonth?.totalSales ?? 0;
    const thisMonthDues  = curMonth?.totalDues  ?? 0;

    return NextResponse.json({
      monthly: result,
      totalRevenue,
      totalDues,
      totalCollection,
      thisMonthSales,
      thisMonthDues,
    });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
