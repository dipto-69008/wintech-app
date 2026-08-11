import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Budget from '@/models/Budget';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const year = searchParams.get('year') ? Number(searchParams.get('year')) : new Date().getFullYear();
    const data = await Budget.find({ year }).sort({ dept: 1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    if (!body.year) body.year = new Date().getFullYear();
    const existing = await Budget.findOne({ dept: body.dept, year: body.year });
    if (existing) {
      const doc = await Budget.findByIdAndUpdate(existing._id, body, { new: true });
      return NextResponse.json(doc);
    }
    const doc = await Budget.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
