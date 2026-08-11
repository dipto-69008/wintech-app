import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Category from '@/models/Category';
import Product from '@/models/Product';

const CATEGORIES = [
  {
    name: 'Probiotics',
    description: 'Probiotic products for fish and aquaculture',
    products: ['Eco Fresh', 'Eco Fesh', 'Eco Fresh Plus', 'Win Pro Aqua'],
  },
  {
    name: 'Water Management',
    description: 'Products for water quality management',
    products: ['Aqua Safe Plus', 'Bottom Light', 'Energy Flow', 'Green Vita', 'Oxy-win', 'Oxy-Win', 'Pro Yucca for Fish'],
  },
  {
    name: 'Disinfectant & Parasiticide',
    description: 'Disinfectants and anti-parasitic products',
    products: ['Bencidal Plus', 'Win Max Plus', 'Win Max plus', 'Winxide Aqua'],
  },
  {
    name: 'Growth Promotors',
    description: 'Products that promote growth in aquaculture',
    products: ['Aqua Milk Premium', 'Aqua Milk Premoium', 'Vitazyme Aqua', 'Win Health'],
  },
  {
    name: 'Immune Booster',
    description: 'Immunity-enhancing supplements for fish',
    products: ['Aqua Amla', 'Brood Plus', 'Liver Win', 'Vitafort Plus', 'Vitafort Aqua', 'Vita Fort Aqua'],
  },
];

export async function POST() {
  try {
    await connectDB();
    let categoriesCreated = 0;
    let productsUpdated = 0;

    for (const cat of CATEGORIES) {
      // Upsert category
      let catDoc = await Category.findOne({ name: cat.name });
      if (!catDoc) {
        catDoc = await Category.create({ name: cat.name, description: cat.description, status: 'a' });
        categoriesCreated++;
      }

      // Assign products to this category by name match (case-insensitive)
      for (const prodName of cat.products) {
        const result = await Product.updateMany(
          { name: { $regex: `^${prodName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, $options: 'i' } },
          { $set: { categoryName: cat.name, categoryId: catDoc._id } }
        );
        productsUpdated += result.modifiedCount;
      }
    }

    return NextResponse.json({
      message: `Done. Categories created: ${categoriesCreated}, Products updated: ${productsUpdated}`,
    });
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Server error' },
      { status: 500 }
    );
  }
}
