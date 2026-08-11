import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import StockTransfer from '@/models/StockTransfer';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const productName = searchParams.get('productName') || '';
    const fromBranch  = searchParams.get('fromBranch') || '';
    const toBranch    = searchParams.get('toBranch') || '';
    const limit       = parseInt(searchParams.get('limit') || '200');

    const query: Record<string, unknown> = {};
    if (productName) query.productName = { $regex: productName, $options: 'i' };
    if (fromBranch)  query.fromBranch  = fromBranch;
    if (toBranch)    query.toBranch    = toBranch;

    const data = await StockTransfer.find(query)
      .sort({ date: -1 })
      .limit(limit)
      .lean();

    // Distinct branches used
    const allFromBranches = await StockTransfer.distinct('fromBranch');
    const allToBranches   = await StockTransfer.distinct('toBranch');
    const branches = [...new Set([...allFromBranches, ...allToBranches])].sort();

    return NextResponse.json({ data, total: data.length, branches });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const { productId, productName, packSize, fromBranch, toBranch, quantity,
            weightGram, weightUnit, pcsCount, transferredBy, notes, date, time, tags } = body;

    if (!productName) return NextResponse.json({ error: 'Product name required' }, { status: 400 });
    if (!fromBranch)  return NextResponse.json({ error: 'From branch required' }, { status: 400 });
    if (!toBranch)    return NextResponse.json({ error: 'To branch required' }, { status: 400 });
    if (!quantity || quantity <= 0)
      return NextResponse.json({ error: 'Quantity must be > 0' }, { status: 400 });

    const transfer = await StockTransfer.create({
      productId: productId || undefined,
      productName, packSize, fromBranch, toBranch,
      quantity: Number(quantity),
      weightGram: weightGram != null ? Number(weightGram) : undefined,
      weightUnit:  weightUnit || undefined,
      pcsCount:   pcsCount   != null ? Number(pcsCount)   : undefined,
      transferredBy, notes,
      date: date ? new Date(date) : new Date(),
      time: time || undefined,
      tags: tags || [],
    });

    return NextResponse.json(transfer, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}
