import mongoose, { Schema, Document } from 'mongoose';

export interface ISurvey extends Document {
  type: 'farmer' | 'dealer';
  workerName: string;
  postingId?: string;
  visitDate: Date;
  // Farmer Visit
  farmName?: string;
  farmerMobile?: string;
  village?: string;
  diseases?: string;
  wintechProducts?: string[];
  prescription?: string;
  // Dealer Visit
  shopName?: string;
  dealerName?: string;
  dealerMobile?: string;
  bazarName?: string;
  wintechStock?: string;
  competitorProduct?: string;
  collectionAmount?: number;
  remarks?: string;
  // Common
  photo?: string;
  status: string;
}

const SurveySchema = new Schema<ISurvey>({
  type:           { type: String, enum: ['farmer', 'dealer'], required: true },
  workerName:     { type: String, required: true, trim: true },
  postingId:      String,
  visitDate:      { type: Date, required: true },
  // Farmer
  farmName:       String,
  farmerMobile:   String,
  village:        String,
  diseases:       String,
  wintechProducts:{ type: [String], default: [] },
  prescription:   String,
  // Dealer
  shopName:       String,
  dealerName:     String,
  dealerMobile:   String,
  bazarName:      String,
  wintechStock:   String,
  competitorProduct: String,
  collectionAmount:  Number,
  remarks:        String,
  // Common
  photo:          String,
  status:         { type: String, default: 'a' },
}, { timestamps: true });

SurveySchema.index({ type: 1, visitDate: -1 });
SurveySchema.index({ workerName: 1 });

export default mongoose.models.Survey || mongoose.model<ISurvey>('Survey', SurveySchema);
