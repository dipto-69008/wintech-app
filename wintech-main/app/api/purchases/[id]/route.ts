import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import PurchaseMaster from '@/models/PurchaseMaster';
import PurchaseDetail from '@/models/PurchaseDetail';

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const master = await PurchaseMaster.findById(id).lean();
    if (!master) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    const details = await PurchaseDetail.find({ purchaseMasterId: id }).lean();
    return NextResponse.json({ ...master, details });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const body = await req.json();
    const { details, ...masterData } = body;
    const master = await PurchaseMaster.findByIdAndUpdate(id, masterData, { new: true }).lean();
    if (!master) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    if (details && Array.isArray(details)) {
      await PurchaseDetail.deleteMany({ purchaseMasterId: id });
      if (details.length > 0) {
        await PurchaseDetail.insertMany(details.map((d: Record<string, unknown>) => ({ ...d, purchaseMasterId: id })));
      }
    }
    const updatedDetails = await PurchaseDetail.find({ purchaseMasterId: id }).lean();
    return NextResponse.json({ ...master, details: updatedDetails });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    await Promise.all([
      PurchaseMaster.findByIdAndDelete(id),
      PurchaseDetail.deleteMany({ purchaseMasterId: id }),
    ]);
    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
