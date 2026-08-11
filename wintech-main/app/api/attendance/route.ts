import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Attendance from '@/models/Attendance';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const weekLabel = searchParams.get('weekLabel') || '';
    const query: Record<string, unknown> = {};
    if (weekLabel) query.weekLabel = weekLabel;
    const data = await Attendance.find(query).sort({ createdAt: -1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const existing = await Attendance.findOne({ weekLabel: body.weekLabel });
    let doc;
    if (existing) {
      doc = await Attendance.findByIdAndUpdate(existing._id, { records: body.records }, { new: true });
    } else {
      doc = await Attendance.create(body);
    }
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
