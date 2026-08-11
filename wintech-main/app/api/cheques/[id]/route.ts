import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Cheque from '@/models/Cheque';

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const cheque = await Cheque.findById(id).lean();
    if (!cheque) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(cheque);
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    const body = await req.json();
    const cheque = await Cheque.findByIdAndUpdate(id, body, { new: true });
    if (!cheque) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(cheque);
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await connectDB();
    const { id } = await params;
    await Cheque.findByIdAndDelete(id);
    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
