import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Payroll from '@/models/Payroll';

export async function PUT(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const body = await req.json();
    const payroll = await Payroll.findByIdAndUpdate(id, body, { new: true });
    if (!payroll) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(payroll);
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    await Payroll.findByIdAndDelete(id);
    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
