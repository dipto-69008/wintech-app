import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Adjustment from '@/models/Adjustment';
import Product from '@/models/Product';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const limit = parseInt(searchParams.get('limit') || '100');
    const data = await Adjustment.find().sort({ createdAt: -1 }).limit(limit).lean();
    return NextResponse.json({ data, total: data.length });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const { productId, type, quantity, reason, adjustedBy } = body;

    const product = await Product.findById(productId);
    if (!product) return NextResponse.json({ error: 'Product not found' }, { status: 404 });

    const previousStock = product.reorderLevel || 0;
    let newStock = previousStock;
    if (type === 'add') newStock = previousStock + quantity;
    else if (type === 'remove') newStock = Math.max(0, previousStock - quantity);

    const adjustment = await Adjustment.create({
      productId, productName: product.name, productCode: product.code,
      type, quantity, reason, adjustedBy, previousStock, newStock,
    });

    await Product.findByIdAndUpdate(productId, { reorderLevel: newStock });

    return NextResponse.json(adjustment, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
