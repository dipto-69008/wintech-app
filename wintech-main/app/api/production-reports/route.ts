import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import ProductionReport from '@/models/ProductionReport';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const month  = searchParams.get('month');
    const year   = searchParams.get('year');
    const search = searchParams.get('search') || '';

    const query: Record<string, unknown> = {};
    if (month) query.month = parseInt(month);
    if (year)  query.year  = parseInt(year);
    if (search) query.productName = { $regex: search, $options: 'i' };

    const data = await ProductionReport.find(query).sort({ productName: 1, packSize: 1 }).limit(500).lean();

    const periods = await ProductionReport.aggregate([
      { $group: { _id: { year: '$year', month: '$month' }, count: { $sum: 1 } } },
      { $sort: { '_id.year': -1, '_id.month': -1 } },
    ]);

    return NextResponse.json({ data, total: data.length, periods });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
