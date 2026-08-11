import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import StockReport from '@/models/StockReport';

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    await connectDB();
    const { id } = await params;
    const body = await req.json();

    const update: Record<string, unknown> = {};
    if ('expiryDate' in body) update.expiryDate = body.expiryDate ? new Date(body.expiryDate) : null;
    if ('damageQty'  in body) update.damageQty  = body.damageQty != null ? Number(body.damageQty) : 0;

    const updated = await StockReport.findByIdAndUpdate(
      id,
      { $set: update },
      { new: true, runValidators: true }
    );
    if (!updated) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(updated);
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}
