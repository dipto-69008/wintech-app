import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import StockReport from '@/models/StockReport';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const month      = searchParams.get('month');
    const year       = searchParams.get('year');
    const reportType = searchParams.get('type') || 'company';
    const zone       = searchParams.get('zone');
    const search     = searchParams.get('search') || '';

    const query: Record<string, unknown> = { reportType };
    if (month) query.month = parseInt(month);
    if (year)  query.year  = parseInt(year);
    if (zone)  query.zone  = zone;
    if (search) query.productName = { $regex: search, $options: 'i' };

    const data = await StockReport.find(query).sort({ productName: 1, packSize: 1 }).limit(500).lean();

    // Summary: available months/years
    const periods = await StockReport.aggregate([
      { $group: { _id: { year: '$year', month: '$month' }, count: { $sum: 1 } } },
      { $sort: { '_id.year': -1, '_id.month': -1 } },
    ]);

    const zones = await StockReport.distinct('zone', { reportType: 'branch' });

    return NextResponse.json({ data, total: data.length, periods, zones });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
