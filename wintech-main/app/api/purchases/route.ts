import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import PurchaseMaster from '@/models/PurchaseMaster';
import PurchaseDetail from '@/models/PurchaseDetail';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');
    const from = searchParams.get('from');
    const to = searchParams.get('to');
    const branchId = searchParams.get('branchId');

    const query: Record<string, unknown> = { status: 'a' };
    if (branchId) query.branchId = parseInt(branchId);
    if (search) query.$or = [
      { invoiceNo: { $regex: search, $options: 'i' } },
      { supplierName: { $regex: search, $options: 'i' } },
    ];
    if (from || to) {
      query.orderDate = {};
      if (from) (query.orderDate as Record<string, unknown>).$gte = new Date(from);
      if (to) (query.orderDate as Record<string, unknown>).$lte = new Date(to);
    }

    const [data, total] = await Promise.all([
      PurchaseMaster.find(query).sort({ orderDate: -1 }).skip((page - 1) * limit).limit(limit).lean(),
      PurchaseMaster.countDocuments(query),
    ]);

    return NextResponse.json({ data, total, page, limit });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const { details, ...masterData } = body;

    const master = await PurchaseMaster.create(masterData);

    if (details && Array.isArray(details) && details.length > 0) {
      await PurchaseDetail.insertMany(
        details.map((d: Record<string, unknown>) => ({ ...d, purchaseMasterId: master._id }))
      );
    }

    return NextResponse.json(master, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
