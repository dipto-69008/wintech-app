import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Unit from '@/models/Unit';

export async function GET() {
  try {
    await connectDB();
    const data = await Unit.find({ status: 'a' }).sort({ name: 1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Unit.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
