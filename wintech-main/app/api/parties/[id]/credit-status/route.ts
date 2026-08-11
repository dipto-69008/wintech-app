import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Party from '@/models/Party';
import SaleMaster from '@/models/SaleMaster';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    await connectDB();
    const { id } = await params;
    const party = await Party.findById(id).lean() as { _id: unknown; creditLimit?: number } | null;
    if (!party) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    const creditLimit = party.creditLimit || 0;
    if (creditLimit <= 0) {
      return NextResponse.json({ creditLimit: 0, currentDue: 0, usagePct: 0, blocked: false, warning: false });
    }

    // Sum all outstanding due amounts for this party
    const agg = await SaleMaster.aggregate([
      { $match: { partyId: party._id, dueAmount: { $gt: 0 }, status: { $nin: ['cancelled', 'returned'] } } },
      { $group: { _id: null, total: { $sum: '$dueAmount' } } },
    ]);
    const currentDue = agg[0]?.total || 0;
    const usagePct = Math.round((currentDue / creditLimit) * 100);

    return NextResponse.json({
      creditLimit,
      currentDue,
      usagePct,
      blocked: usagePct >= 100,
      warning: usagePct >= 70,
    });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
