import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import SaleMaster from '@/models/SaleMaster';

export async function POST(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const sale = await SaleMaster.findByIdAndUpdate(
      id,
      { status: 'a', isOrder: 'approved' },
      { new: true }
    );
    if (!sale) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(sale);
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
