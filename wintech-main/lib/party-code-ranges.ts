export interface PartyCodeRange {
  zone: string;
  codeRange: string;
  assignedOfficer?: string;
}

/** Zone-wise party code allocation supplied by the business team. */
export const PARTY_CODE_RANGES: PartyCodeRange[] = [
  { zone: 'Gouripur', codeRange: 'Mym-0001 - 0050', assignedOfficer: 'Md. Abu Sayed' },
  { zone: 'Tarakanda', codeRange: 'Mym-0051 - 0100', assignedOfficer: 'Md. Abu Hanif' },
  { zone: 'Fulpur', codeRange: 'Mym-0101 - 0150', assignedOfficer: 'Md. Abdus Selim' },
  { zone: 'Netrokona', codeRange: 'Mym-0151 - 0200' },
  { zone: 'Fulbaria', codeRange: 'Mym-0201 - 0250', assignedOfficer: 'Md. Shaiem Akand' },
  { zone: 'Muktagasa', codeRange: 'Mym-0251 - 0300', assignedOfficer: 'Md. Shaiem Akand' },
  { zone: 'Comilla-1', codeRange: 'Com-1001 - 1050', assignedOfficer: 'Md. Ashraful Islam' },
  { zone: 'Comilla-2', codeRange: 'Com-1051 - 1100' },
  { zone: 'Comilla-3', codeRange: 'Com-1101 - 1150', assignedOfficer: 'Pobitro Kumar Mondol' },
  { zone: 'Comilla-4', codeRange: 'Com-1151 - 1200', assignedOfficer: 'Md. Hijbul Bahar' },
  { zone: 'Feni-1', codeRange: 'Feni-1201 - 1250', assignedOfficer: 'Mr. Joyonta Das' },
  { zone: 'Feni-2', codeRange: 'Feni-1251 - 1300' },
  { zone: 'Jessore-1', codeRange: 'Jess-2001 - 2050', assignedOfficer: 'Mr. Hasib Sikder' },
  { zone: 'Jessore-2 [Bakra]', codeRange: 'Jess-2051 - 2100', assignedOfficer: 'Mr. Shankar Kumar Das' },
  { zone: 'Bogura-1', codeRange: 'Bog-2501 - 2550', assignedOfficer: 'Mr. Sorowar Hossain' },
  { zone: 'Bogura-2', codeRange: 'Bog-2551 - 2600', assignedOfficer: 'Mr. Rasel Ali' },
];