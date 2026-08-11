import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import StockTransfer from '@/models/StockTransfer';

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    await connectDB();
    const { id } = await params;
    const deleted = await StockTransfer.findByIdAndDelete(id);
    if (!deleted) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json({ ok: true });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    await connectDB();
    const { id } = await params;
    const body = await req.json();
    const { productId, productName, packSize, fromBranch, toBranch, quantity,
            weightGram, weightUnit, pcsCount, transferredBy, notes, date, time, tags } = body;
    const updated = await StockTransfer.findByIdAndUpdate(
      id,
      {
        $set: {
          productId:      productId || undefined,
          productName,
          packSize:      packSize      ?? '',
          fromBranch,
          toBranch,
          quantity:      Number(quantity),
          weightGram:    weightGram != null ? Number(weightGram) : undefined,
          weightUnit:    weightUnit || undefined,
          pcsCount:      pcsCount   != null ? Number(pcsCount)   : undefined,
          transferredBy: transferredBy ?? '',
          notes:         notes         ?? '',
          date:          date ? new Date(date) : undefined,
          time:          time ?? '',
          tags:          tags  ?? [],
        },
      },
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
