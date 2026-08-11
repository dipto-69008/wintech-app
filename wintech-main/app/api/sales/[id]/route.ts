import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SaleMaster from '@/models/SaleMaster';
import SaleDetail from '@/models/SaleDetail';

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const master = await SaleMaster.findById(id).lean();
    if (!master) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    const details = await SaleDetail.find({ saleMasterId: id }).lean();
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

    const master = await SaleMaster.findByIdAndUpdate(id, masterData, { new: true }).lean();
    if (!master) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    if (details && Array.isArray(details)) {
      await SaleDetail.deleteMany({ saleMasterId: id });
      if (details.length > 0) {
        await SaleDetail.insertMany(details.map((d: Record<string, unknown>) => ({ ...d, saleMasterId: id })));
      }
    }

    const updatedDetails = await SaleDetail.find({ saleMasterId: id }).lean();
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
      SaleMaster.findByIdAndDelete(id),
      SaleDetail.deleteMany({ saleMasterId: id }),
    ]);
    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
