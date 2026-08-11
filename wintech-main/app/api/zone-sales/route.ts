import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import ZoneSalesReport from '@/models/ZoneSalesReport';

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
    if (zone && !search) query.zone = zone;
    if (search) query.zone = { $regex: search, $options: 'i' };

    const data = await ZoneSalesReport.find(query)
      .sort({ year: -1, month: -1, zone: 1 })
      .limit(2000)
      .lean();

    const periods = await ZoneSalesReport.aggregate([
      { $group: { _id: { year: '$year', month: '$month' }, count: { $sum: 1 } } },
      { $sort: { '_id.year': -1, '_id.month': -1 } },
    ]);

    const zones = await ZoneSalesReport.distinct('zone');

    return NextResponse.json({ data, total: data.length, periods, zones });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}
