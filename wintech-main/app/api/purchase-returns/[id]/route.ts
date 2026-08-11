import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import PurchaseReturn from '@/models/PurchaseReturn';
import PurchaseReturnDetail from '@/models/PurchaseReturnDetail';

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const master = await PurchaseReturn.findById(id).lean();
    if (!master) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    const details = await PurchaseReturnDetail.find({ purchaseReturnId: id }).lean();
    return NextResponse.json({ ...master, details });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    await PurchaseReturn.findByIdAndDelete(id);
    await PurchaseReturnDetail.deleteMany({ purchaseReturnId: id });
    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
