import mongoose, { Schema, Document } from 'mongoose';

export interface IParty extends Document {
  legacyId?: number;
  code: string;
  name: string;
  type?: string;
  phone?: string;
  mobile?: string;
  contactPerson?: string;
  email?: string;
  officePhone?: string;
  address?: string;
  ownerName?: string;
  area?: string;
  web?: string;
  creditLimit?: number;
  previousDue?: number;
  status: string;
  branchId?: number;
  employeeId?: number;
  addBy?: string;
  addTime?: Date;
  creditReminderSent?: string[]; // tracks '70pct', '90pct' thresholds already notified
}

const PartySchema = new Schema<IParty>({
  legacyId: { type: Number, index: true },
  code: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true },
  type: String,
  phone: String,
  mobile: String,
  contactPerson: String,
  email: String,
  officePhone: String,
  address: String,
  ownerName: String,
  area: String,
  web: String,
  creditLimit: { type: Number, default: 0 },
  previousDue: { type: Number, default: 0 },
  status: { type: String, default: 'a' },
  creditReminderSent: { type: [String], default: [] },
  branchId: Number,
  employeeId: Number,
  addBy: String,
  addTime: Date,
}, { timestamps: true });

PartySchema.index({ code: 1 });
PartySchema.index({ name: 'text', mobile: 1 });

export default mongoose.models.Party || mongoose.model<IParty>('Party', PartySchema, 'parties');
