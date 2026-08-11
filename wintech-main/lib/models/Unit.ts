import mongoose, { Schema, Document } from 'mongoose';

export interface IUnit extends Document {
  legacyId?: number;
  name: string;
  status: string;
  addBy?: string;
}

const UnitSchema = new Schema<IUnit>({
  legacyId: { type: Number, index: true },
  name: { type: String, required: true, trim: true },
  status: { type: String, default: 'a' },
  addBy: String,
}, { timestamps: true });

export default mongoose.models.Unit || mongoose.model<IUnit>('Unit', UnitSchema);
