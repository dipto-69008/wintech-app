import mongoose, { Schema, Document } from 'mongoose';

export interface IProduct extends Document {
  legacyId?: number;
  code: string;
  name: string;
  groupId?: number;
  categoryId?: mongoose.Types.ObjectId;
  categoryName?: string;
  color?: string;
  brand?: string;
  size?: string;
  vat?: number;
  reorderLevel?: number;
  purchaseRate: number;
  sellingPrice: number;
  minSellingPrice?: number;
  wholesaleRate?: number;
  oneCartonEqual?: string;
  isService?: boolean;
  unit?: string;
  status: string;
  branchId?: number;
  addBy?: string;
  addTime?: Date;
  image?: string;
  stock?: number;
  stockCumilla?: number;
  stockMymensingh?: number;
  stockBogra?: number;
  stockJessore?: number;
  stockFeni?: number;
  packSize?: string;
  expiryDate?: Date;
  expiryReminderSent?: ('3month' | '2month')[];
  bonusTriggerQty?: number;
  bonusFreeQty?: number;
}

const ProductSchema = new Schema<IProduct>({
  legacyId: { type: Number, index: true },
  code: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true },
  groupId: Number,
  categoryId: { type: Schema.Types.ObjectId, ref: 'Category' },
  categoryName: String,
  color: String,
  brand: String,
  size: String,
  vat: { type: Number, default: 0 },
  reorderLevel: { type: Number, default: 0 },
  purchaseRate: { type: Number, required: true, default: 0 },
  sellingPrice: { type: Number, required: true, default: 0 },
  minSellingPrice: { type: Number, default: 0 },
  wholesaleRate: { type: Number, default: 0 },
  oneCartonEqual: String,
  isService: { type: Boolean, default: false },
  unit: String,
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
  addTime: Date,
  image: String,
  stock: { type: Number, default: 0 },
  stockCumilla: { type: Number, default: 0 },
  stockMymensingh: { type: Number, default: 0 },
  stockBogra: { type: Number, default: 0 },
  stockJessore: { type: Number, default: 0 },
  stockFeni: { type: Number, default: 0 },
  packSize:             { type: String, default: '' },
  expiryDate:           Date,
  expiryReminderSent:   [{ type: String }],
  bonusTriggerQty:      { type: Number, default: 0 },
  bonusFreeQty:         { type: Number, default: 0 },
}, { timestamps: true });

ProductSchema.index({ code: 1 });
ProductSchema.index({ name: 'text' });

export default mongoose.models.Product || mongoose.model<IProduct>('Product', ProductSchema);
