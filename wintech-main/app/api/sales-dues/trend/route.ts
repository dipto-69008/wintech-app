import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SalesDuesReport from '@/models/SalesDuesReport';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const zone = searchParams.get('zone') || '';
    const year = searchParams.get('year') || '';

    const match: Record<string, unknown> = {};
    if (zone) match.zone = zone;
    if (year) match.year = parseInt(year);

    const monthly = await SalesDuesReport.aggregate([
      ...(Object.keys(match).length ? [{ $match: match }] : []),
      {
        $group: {
          _id: { year: '$year', month: '$month' },
          totalPreviousDue: { $sum: '$previousDue' },
          totalSales:       { $sum: '$totalSales' },
          totalCollection:  { $sum: '$collectionAmount' },
          totalDues:        { $sum: '$totalDues' },
          totalCommission:  { $sum: '$commission' },
          totalReturn:      { $sum: '$returnGoods' },
          partyCount:       { $sum: 1 },
        },
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]);

    const zoneMonthly = zone ? [] : await SalesDuesReport.aggregate([
      ...(year ? [{ $match: { year: parseInt(year) } }] : []),
      {
        $group: {
          _id: { zone: '$zone', year: '$year', month: '$month' },
          totalSales:      { $sum: '$totalSales' },
          totalCollection: { $sum: '$collectionAmount' },
          totalDues:       { $sum: '$totalDues' },
        },
      },
      { $sort: { '_id.zone': 1, '_id.year': 1, '_id.month': 1 } },
    ]);

    return NextResponse.json({ monthly, zoneMonthly });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
