import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SalesDuesReport from '@/models/SalesDuesReport';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const month  = searchParams.get('month');
    const year   = searchParams.get('year');
    const zone   = searchParams.get('zone');
    const search = searchParams.get('search') || '';

    const query: Record<string, unknown> = {};
    if (month) query.month = parseInt(month);
    if (year)  query.year  = parseInt(year);
    if (zone)  query.zone  = zone;
    if (search) query.partyName = { $regex: search, $options: 'i' };

    const data = await SalesDuesReport.find(query).sort({ zone: 1, partyName: 1 }).limit(1000).lean();

    const periods = await SalesDuesReport.aggregate([
      { $group: { _id: { year: '$year', month: '$month' }, count: { $sum: 1 } } },
      { $sort: { '_id.year': -1, '_id.month': -1 } },
    ]);

    const zones = await SalesDuesReport.distinct('zone');

    // Zone summary
    const zoneSummary = await SalesDuesReport.aggregate([
      ...(month ? [{ $match: { month: parseInt(month) } }] : []),
      ...(year  ? [{ $match: { year:  parseInt(year)  } }] : []),
      {
        $group: {
          _id: '$zone',
          totalPreviousDue: { $sum: '$previousDue' },
          totalSales:       { $sum: '$totalSales' },
          totalCollection:  { $sum: '$collectionAmount' },
          totalDues:        { $sum: '$totalDues' },
          partyCount:       { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    return NextResponse.json({ data, total: data.length, periods, zones, zoneSummary });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
